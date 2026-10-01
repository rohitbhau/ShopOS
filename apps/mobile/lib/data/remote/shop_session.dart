import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/permissions.dart';
import '../../domain/shop_models.dart';
import '../local/shop_database.dart';
import '../local/shop_store.dart';
import '../sync/sync_engine.dart';

class SupabaseSyncGateway implements RemoteSyncGateway {
  SupabaseSyncGateway(this.client,this.store);
  final SupabaseClient client;
  final ShopStore store;
  @override
  Future<void> push(QueuedMutation mutation) async {
    if(client.auth.currentUser?.id != store.userId || client.auth.currentUser?.appMetadata['tenant_id'] != store.tenantId) throw StateError('Shop session changed. Sign in to the original shop to sync.');
    if(mutation.payload['_tenant_id']!=store.tenantId) throw StateError('Queued change belongs to another shop');
    final changes=mutation.entity=='_batch'?List<Map<String,dynamic>>.from(mutation.payload['mutations']):[mutation.toJson()];
    // Shop profile updates are idempotent and go through the tenant RLS policy.
    for(final change in changes.where((item)=>item['entity']=='_tenant')) {
      final payload=Map<String,dynamic>.from(change['payload'])..remove('updated_at');
      await client.from('tenants').update(payload).eq('id',store.tenantId);
    }
    final recordChanges=changes.where((item)=>item['entity']!='_tenant').toList();
    if(recordChanges.isNotEmpty) await client.rpc('sync_mutations',params:{'p_mutations':recordChanges});
  }
}

class ShopSession {
  ShopSession(this.client,this.database);
  final SupabaseClient client;
  final ShopDatabase database;
  ShopStore? store;
  SyncEngine? engine;
  StreamSubscription<ConnectivityResult>? _connectivity;
  StreamSubscription<SyncStatus>? _status;
  Future<ShopStore?> load() async {
    final user=client.auth.currentUser;
    if(user==null)return null;
    String? tenantId=user.appMetadata['tenant_id'] as String?;
    // Resolve membership only when online; cached signed claims allow offline billing.
    try {
      await client.functions.invoke('auth-set-tenant-claim',body:{if(tenantId!=null)'tenant_id':tenantId});
      await client.auth.refreshSession();
      tenantId=client.auth.currentUser?.appMetadata['tenant_id'] as String?;
    } catch (_) { if(tenantId==null) rethrow; }
    if(tenantId==null)return null;
    final roleName=client.auth.currentUser?.appMetadata['shop_role']??'viewer';
    final next=ShopStore(database:database,tenantId:tenantId,userId:user.id,demo:false,
      role:ShopRole.values.firstWhere((item)=>item.name==roleName,orElse:()=>ShopRole.viewer));
    await next.initialize();
    store=next;
    engine=SyncEngine(outbox:next.persistentOutbox!,gateway:SupabaseSyncGateway(client,next),
      isOnline:() async => await Connectivity().checkConnectivity()!=ConnectivityResult.none,
      onSynced:pull);
    _status=engine!.statusStream.listen((_)=>next.refreshOutbox());
    _connectivity=Connectivity().onConnectivityChanged.listen((result){if(result!=ConnectivityResult.none)engine?.syncNow();});
    engine!.start();
    // An existing local shop remains usable when the first pull cannot reach the server.
    if(!next.isOnboarded) await pull();
    return next;
  }
  Future<void> pull() async {
    final current=store; if(current==null)return;
    final tenant=await client.from('tenants').select().eq('id',current.tenantId).single();
    final apps=await client.from('apps').select('id,template_key').eq('tenant_id',current.tenantId).order('created_at');
    final schemaMap=<String,Map<String,dynamic>>{};
    if(apps.isNotEmpty) {
      tenant['template_key']=apps.first['template_key'];
      final entities=await client.from('entities').select().inFilter('app_id',apps.map((app)=>app['id']).toList());
      for(final entity in entities) {schemaMap[entity['name']]={...Map<String,dynamic>.from(entity['schema']),'label':entity['label']};}
    }
    // Cursor includes UUID tie-breaker. Persisted data first, cursor second: a crash only replays reads.
    final cursorKey='pull:${current.tenantId}';
    final cursorRows=await (database.select(database.localRecords)..where((r)=>r.id.equals(cursorKey))).get();
    String? since, afterId;
    if(cursorRows.isNotEmpty) {
      final cursor=await database.readJson(cursorKey); since=cursor?['since'];afterId=cursor?['id'];
    }
    while(true) {
      final response=await client.rpc('pull_records',params:{'p_since':since,'p_after_id':afterId,'p_limit':500});
      final rows=(response as List).map((row)=>Map<String,dynamic>.from(row)).toList();
      await current.applyRemote(rows,entitySchemas:schemaMap,tenant:tenant);
      if(rows.isEmpty) break;
      since=rows.last['updated_at'];afterId=rows.last['id'];
      await database.saveRecord(id:cursorKey,tenantId:current.tenantId,entity:'_cursor',data:{'since':since,'id':afterId},createdAt:DateTime.now(),updatedAt:DateTime.now());
      if(rows.length<500)break;
    }
  }
  void dispose() { _connectivity?.cancel();_status?.cancel();engine?.dispose(); }
}
