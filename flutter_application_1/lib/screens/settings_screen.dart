import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'login_screen.dart';
import 'account_integration_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userEmail = '';
  String _authToken = '';
  bool _useBioAuth = false;
  bool _enableNotifications = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _userEmail = prefs.getString('userEmail') ?? '로그인 정보 없음';
      _authToken = prefs.getString('authToken') ?? '';
      _useBioAuth = prefs.getBool('useBioAuth') ?? false;
      _enableNotifications = prefs.getBool('enableNotifications') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _toggleBioAuth(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useBioAuth', value);
    if (!mounted) return;
    setState(() => _useBioAuth = value);
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableNotifications', value);
    if (!mounted) return;
    setState(() => _enableNotifications = value);
  }

  void _clearCache() {
    ApiService.clearCache();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('금융 데이터 캐시가 성공적으로 초기화되었습니다.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _goToIntegration() async {
    if (_userEmail.isEmpty || _userEmail == '로그인 정보 없음') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인된 사용자 이메일이 없습니다.')));
      return;
    }

    if (_authToken.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증 토큰이 없습니다. 다시 로그인해주세요.')));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AccountIntegrationScreen(email: _userEmail, authToken: _authToken),
      ),
    );

    if (!mounted) return;
    _clearCache();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '로그아웃',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userEmail');
      await prefs.remove('authToken');
      ApiService.clearCache();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '설정',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4A00E0)),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4A00E0,
                                ).withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userEmail.contains('@')
                              ? _userEmail.split('@').first
                              : _userEmail,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF212529),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userEmail,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('금융 데이터 관리'),
                  _buildCardGroup([
                    _buildSettingsTile(
                      icon: Icons.refresh_rounded,
                      iconBgColor: Colors.blue.shade50,
                      iconColor: Colors.blue.shade700,
                      title: '금융 데이터 캐시 비우기',
                      subtitle: '자산 및 거래 내역을 강제로 새로 불러옵니다.',
                      onTap: _clearCache,
                    ),
                    _buildDivider(),
                    _buildSettingsTile(
                      icon: Icons.link_rounded,
                      iconBgColor: Colors.purple.shade50,
                      iconColor: Colors.purple.shade700,
                      title: '계좌 정보 재연동',
                      subtitle: '연동된 은행 및 카드 정보를 업데이트합니다.',
                      onTap: _goToIntegration,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionTitle('앱 설정 및 보안'),
                  _buildCardGroup([
                    _buildSwitchTile(
                      icon: Icons.fingerprint_rounded,
                      iconBgColor: Colors.teal.shade50,
                      iconColor: Colors.teal.shade700,
                      title: '생체 인증 (지문 / Face ID)',
                      value: _useBioAuth,
                      onChanged: _toggleBioAuth,
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      icon: Icons.notifications_active_rounded,
                      iconBgColor: Colors.orange.shade50,
                      iconColor: Colors.orange.shade700,
                      title: '거래 및 혜택 알림 수신',
                      value: _enableNotifications,
                      onChanged: _toggleNotifications,
                    ),
                    _buildDivider(),
                    _buildInfoTile(
                      icon: Icons.dns_rounded,
                      iconBgColor: Colors.indigo.shade50,
                      iconColor: Colors.indigo.shade700,
                      title: '서버 연결 정보',
                      trailingText: ApiConfig.baseUrl.contains('10.0.2.2')
                          ? '에뮬레이터'
                          : '실제 서버',
                    ),
                    _buildDivider(),
                    _buildInfoTile(
                      icon: Icons.info_outline_rounded,
                      iconBgColor: Colors.grey.shade100,
                      iconColor: Colors.grey.shade700,
                      title: '앱 버전',
                      trailingText: '1.0.0 (최신)',
                    ),
                  ]),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.red.shade100),
                          ),
                        ),
                        child: const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF212529),
          letterSpacing: -0.3,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                letterSpacing: -0.2,
              ),
            ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.black26,
        size: 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF212529),
          letterSpacing: -0.3,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF4A00E0),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String trailingText,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF212529),
          letterSpacing: -0.3,
        ),
      ),
      trailing: Text(
        trailingText,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 62,
      endIndent: 20,
    );
  }
}
