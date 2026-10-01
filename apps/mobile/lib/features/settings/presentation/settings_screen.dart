import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _shopData;
  Map<String, dynamic>? _userData;
  String _selectedLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load user data
      final userResponse = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      _userData = userResponse;

      // Load shop data from tenant
      final tenantId = _supabase.auth.currentUser?.userMetadata?['tenant_id'];
      if (tenantId != null) {
        final tenantResponse = await _supabase
            .from('tenants')
            .select()
            .eq('id', tenantId)
            .single();
        _shopData = tenantResponse;
      }

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _supabase.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  Future<void> _editShopProfile() async {
    if (_shopData == null) return;

    final nameController = TextEditingController(text: _shopData!['name']);
    final phoneController = TextEditingController(text: _shopData!['phone']);
    final emailController = TextEditingController(text: _shopData!['email']);
    final addressController = TextEditingController(text: _shopData!['address']);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Shop Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Shop Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text,
                'phone': phoneController.text,
                'email': emailController.text,
                'address': addressController.text,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      await _supabase.from('tenants').update({
        'name': result['name'],
        'phone': result['phone'],
        'email': result['email'],
        'address': result['address'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _shopData!['id']);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update shop profile: $e')),
        );
      }
    }
  }

  Future<void> _editUserProfile() async {
    if (_userData == null) return;

    final nameController = TextEditingController(text: _userData!['name']);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    try {
      await _supabase.from('users').update({
        'name': result,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _userData!['id']);

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update user profile: $e')),
        );
      }
    }
  }

  void _changeLanguage(String language) {
    setState(() {
      _selectedLanguage = language;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Language changed to ${_getLanguageName(language)}')),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिन्दी';
      case 'ta':
        return 'தமிழ்';
      case 'te':
        return 'తెలుగు';
      case 'bn':
        return 'বাংলা';
      default:
        return 'English';
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'ShopOS',
      applicationVersion: '1.0.0',
      applicationIcon: const FlutterLogo(size: 48),
      applicationLegalese: '© 2026 ShopOS\nBuilt for small businesses in India',
      children: [
        const SizedBox(height: 16),
        const Text(
          'ShopOS is a complete point-of-sale and business management solution '
          'designed for small shops and retailers. Features include:\n\n'
          '• Product Management\n'
          '• Billing & Invoicing\n'
          '• Customer Management\n'
          '• Reports & Analytics\n'
          '• Offline-first operation\n'
          '• Multi-language support',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Shop Profile Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Shop Profile',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          if (_shopData != null) ...[
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.store),
              ),
              title: Text(_shopData!['name'] ?? 'Shop Name'),
              subtitle: Text(_shopData!['shop_type'] ?? 'General'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editShopProfile,
              ),
            ),
            if (_shopData!['phone'] != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone'),
                subtitle: Text(_shopData!['phone']),
              ),
            if (_shopData!['email'] != null)
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(_shopData!['email']),
              ),
            if (_shopData!['address'] != null)
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Address'),
                subtitle: Text(_shopData!['address']),
              ),
          ],
          const Divider(),

          // User Profile Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'User Profile',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          if (_userData != null) ...[
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(_userData!['name'] ?? 'User Name'),
              subtitle: Text(_userData!['phone'] ?? 'Phone'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editUserProfile,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Role'),
              subtitle: Text(_userData!['role'] ?? 'user'),
            ),
          ],
          const Divider(),

          // App Settings Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'App Settings',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(_getLanguageName(_selectedLanguage)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Language'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        title: const Text('English'),
                        value: 'en',
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _changeLanguage(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('हिन्दी (Hindi)'),
                        value: 'hi',
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _changeLanguage(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('தமிழ் (Tamil)'),
                        value: 'ta',
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _changeLanguage(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('తెలుగు (Telugu)'),
                        value: 'te',
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _changeLanguage(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('বাংলা (Bengali)'),
                        value: 'bn',
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            _changeLanguage(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(),

          // About & Support Section
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'About & Support',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About ShopOS'),
            onTap: _showAbout,
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact support: support@shopos.com')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening privacy policy...')),
              );
            },
          ),
          const Divider(),

          // Logout Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
