import 'package:flutter/material.dart';
import '../../services/supabase_user_service.dart';
import '../../l10n/app_localizations.dart';
import '../../services/supabase_payment_service.dart';
import '../../models/user_model.dart';
import '../../models/payment_model.dart';
import '../../constants/app_constants.dart';
import '../../theme/theme.dart';

/// Admin user management screen with CRUD operations
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final SupabaseUserService _userService = SupabaseUserService();
  final SupabasePaymentService _paymentService = SupabasePaymentService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  List<String> _availableAreas = [];

  UserRole? _selectedRole;
  String? _selectedArea;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadAreas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);
      final users = await _userService.getAllUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${AppConstants.errorLoadingUsers}: $e')));
      }
    }
  }

  Future<void> _loadAreas() async {
    try {
      final areas = await _userService.getAllAreas();
      setState(() => _availableAreas = areas);
    } catch (e) {
      // Handle error silently for areas
    }
  }

  void _filterUsers() {
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final matchesSearch =
            _searchQuery.isEmpty ||
            user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user.phoneNumber.contains(_searchQuery) ||
            user.address.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesRole = _selectedRole == null || user.role == _selectedRole;
        final matchesArea = _selectedArea == null || user.area == _selectedArea;

        return matchesSearch && matchesRole && matchesArea;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _filterUsers();
  }

  void _onRoleFilterChanged(UserRole? role) {
    setState(() => _selectedRole = role);
    _filterUsers();
  }

  void _onAreaFilterChanged(String? area) {
    setState(() => _selectedArea = area);
    _filterUsers();
  }

  void _clearFilters() {
    setState(() {
      _selectedRole = null;
      _selectedArea = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _filterUsers();
  }

  Future<void> _showUserDialog({UserModel? user}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => UserFormDialog(
        user: user,
        userService: _userService,
        availableAreas: _availableAreas,
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.deleteUserConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _userService.deleteUser(user.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.userDeletedSuccessfully)));
          _loadUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete user: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userManagement),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: l10n.refreshStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilters(l10n, theme),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildUsersList(l10n, theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        tooltip: l10n.addUser,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilters(AppLocalizations l10n, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchUsers,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),

            const SizedBox(height: 16),

            // Filters Row
            Row(
              children: [
                // Role Filter
                Expanded(
                  child: DropdownButtonFormField<UserRole?>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: l10n.filterByRole,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<UserRole?>(
                        value: null,
                        child: Text(l10n.allRoles),
                      ),
                      DropdownMenuItem<UserRole?>(
                        value: UserRole.USER,
                        child: Text(l10n.user),
                      ),
                      DropdownMenuItem<UserRole?>(
                        value: UserRole.COLLECTOR,
                        child: Text(l10n.collector),
                      ),
                      DropdownMenuItem<UserRole?>(
                        value: UserRole.ADMIN,
                        child: Text(l10n.admin),
                      ),
                    ],
                    onChanged: _onRoleFilterChanged,
                  ),
                ),

                const SizedBox(width: 16),

                // Area Filter
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedArea,
                    decoration: InputDecoration(
                      labelText: l10n.filterByArea,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.allAreas),
                      ),
                      ..._availableAreas.map(
                        (area) => DropdownMenuItem<String?>(
                          value: area,
                          child: Text(area),
                        ),
                      ),
                    ],
                    onChanged: _onAreaFilterChanged,
                  ),
                ),

                const SizedBox(width: 16),

                // Clear Filters Button
                IconButton(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all),
                  tooltip: l10n.clearAll,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList(AppLocalizations l10n, ThemeData theme) {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noUsersFound,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.usersWillAppearHere,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user, l10n, theme);
      },
    );
  }

  Widget _buildUserCard(
    UserModel user,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
          child: Icon(_getRoleIcon(user.role), color: _getRoleColor(user.role)),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.phoneNumber),
            Text(
              '${_getRoleDisplayName(user.role, l10n)} • ${user.area}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: user.isActive
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.isActive ? l10n.active : l10n.inactive,
                style: TextStyle(
                  color: user.isActive ? Colors.green : Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showUserDialog(user: user);
                    break;
                  case 'delete':
                    _deleteUser(user);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 16),
                      const SizedBox(width: 8),
                      Text(l10n.editUser),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        l10n.deleteUser,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [_buildUserDetails(user, l10n, theme)],
      ),
    );
  }

  Widget _buildUserDetails(
    UserModel user,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.userDetails,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _buildDetailRow(l10n.address, user.address, theme),
          _buildDetailRow(
            l10n.walletBalance,
            '₹${user.walletBalance.toStringAsFixed(2)}',
            theme,
          ),
          _buildDetailRow(l10n.joinedDate, _formatDate(user.createdAt), theme),
          _buildDetailRow(
            l10n.lastPayment,
            user.lastPaymentDate != null
                ? _formatDate(user.lastPaymentDate!)
                : l10n.never,
            theme,
          ),

          const SizedBox(height: 16),

          // User Activity Section
          FutureBuilder<Map<String, dynamic>>(
            future: _getUserActivity(user.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final activity = snapshot.data ?? {};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.userActivity,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    l10n.paymentCount,
                    '${activity['paymentCount'] ?? 0}',
                    theme,
                  ),
                  _buildDetailRow(
                    l10n.totalPaid,
                    '₹${(activity['totalPaid'] ?? 0.0).toStringAsFixed(2)}',
                    theme,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getUserActivity(String userId) async {
    try {
      final payments = await _paymentService.getPaymentsByUserId(userId);
      final approvedPayments = payments
          .where((p) => p.status == PaymentStatus.APPROVED)
          .toList();

      return {
        'paymentCount': approvedPayments.length,
        'totalPaid': approvedPayments.fold<double>(
          0,
          (sum, payment) => sum + payment.totalAmount,
        ),
      };
    } catch (e) {
      return {'paymentCount': 0, 'totalPaid': 0.0};
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.ADMIN:
        return Colors.red;
      case UserRole.COLLECTOR:
        return Colors.blue;
      case UserRole.USER:
        return Colors.green;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.ADMIN:
        return Icons.admin_panel_settings;
      case UserRole.COLLECTOR:
        return Icons.work;
      case UserRole.USER:
        return Icons.person;
    }
  }

  String _getRoleDisplayName(UserRole role, AppLocalizations l10n) {
    switch (role) {
      case UserRole.ADMIN:
        return l10n.admin;
      case UserRole.COLLECTOR:
        return l10n.collector;
      case UserRole.USER:
        return l10n.user;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Dialog for adding/editing users
class UserFormDialog extends StatefulWidget {
  final UserModel? user;
  final SupabaseUserService userService;
  final List<String> availableAreas;

  const UserFormDialog({
    super.key,
    this.user,
    required this.userService,
    required this.availableAreas,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _areaController = TextEditingController();

  UserRole _selectedRole = UserRole.USER;
  String _selectedLanguage = 'en';
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nameController.text = widget.user!.name;
      _phoneController.text = widget.user!.phoneNumber;
      _addressController.text = widget.user!.address;
      _areaController.text = widget.user!.area;
      _selectedRole = widget.user!.role;
      _selectedLanguage = widget.user!.preferredLanguage;
      _isActive = widget.user!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final l10n = AppLocalizations.of(context)!;

      // Check if phone number already exists (for new users or changed phone)
      if (widget.user == null ||
          widget.user!.phoneNumber != _phoneController.text) {
        final existingUser = await widget.userService.getUserByPhoneNumber(
          _phoneController.text,
        );
        if (existingUser != null) {
          throw Exception(l10n.phoneNumberAlreadyExists);
        }
      }

      if (widget.user == null) {
        // Create new user
        final newUser = UserModel(
          id: '', // Will be set by Firestore
          username: _nameController.text.trim().toLowerCase().replaceAll(' ', '_'), // Generate username from name
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          area: _areaController.text.trim(),
          role: _selectedRole,
          preferredLanguage: _selectedLanguage,
          createdAt: DateTime.now(),
          isActive: _isActive,
        );

        await widget.userService.createUser(newUser);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.userCreatedSuccessfully)));
        }
      } else {
        // Update existing user
        final updatedUser = widget.user!.copyWith(
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          area: _areaController.text.trim(),
          role: _selectedRole,
          preferredLanguage: _selectedLanguage,
          isActive: _isActive,
        );

        await widget.userService.updateUserModel(updatedUser);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.userUpdatedSuccessfully)));
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.user == null ? l10n.addUser : l10n.editUser),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    hintText: l10n.enterName,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => UserModel.validateName(value),
                ),

                const SizedBox(height: 16),

                // Phone Number Field
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: l10n.phoneNumber,
                    hintText: l10n.enterPhoneNumber,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => UserModel.validatePhoneNumber(value),
                ),

                const SizedBox(height: 16),

                // Address Field
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: l10n.address,
                    hintText: l10n.enterAddress,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) => UserModel.validateAddress(value),
                ),

                const SizedBox(height: 16),

                // Area Field with Autocomplete
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _areaController.text),
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return widget.availableAreas;
                    }
                    return widget.availableAreas.where(
                      (area) => area.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                    );
                  },
                  onSelected: (area) => _areaController.text = area,
                  fieldViewBuilder:
                      (context, controller, focusNode, onEditingComplete) {
                        _areaController.text = controller.text;
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete: onEditingComplete,
                          decoration: InputDecoration(
                            labelText: l10n.area,
                            hintText: l10n.selectArea,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) => UserModel.validateArea(value),
                        );
                      },
                ),

                const SizedBox(height: 16),

                // Role Dropdown
                DropdownButtonFormField<UserRole>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: l10n.role,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: UserRole.USER,
                      child: Text(l10n.user),
                    ),
                    DropdownMenuItem(
                      value: UserRole.COLLECTOR,
                      child: Text(l10n.collector),
                    ),
                    DropdownMenuItem(
                      value: UserRole.ADMIN,
                      child: Text(l10n.admin),
                    ),
                  ],
                  onChanged: (role) => setState(() => _selectedRole = role!),
                ),

                const SizedBox(height: 16),

                // Language Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: InputDecoration(
                    labelText: l10n.language,
                    border: const OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'gu', child: Text('ગુજરાતી')),
                  ],
                  onChanged: (language) =>
                      setState(() => _selectedLanguage = language!),
                ),

                const SizedBox(height: 16),

                // Active Status Switch
                SwitchListTile(
                  title: Text(l10n.active),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveUser,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
