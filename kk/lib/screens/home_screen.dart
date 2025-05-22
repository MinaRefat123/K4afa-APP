import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:k4afa/screens/login_screen.dart';
import 'package:k4afa/screens/book_details_screen.dart';
import 'package:k4afa/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String searchQuery = '';
  final AuthService _authService = AuthService();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _authorController = TextEditingController();
  final _linkController = TextEditingController();
  final _adminEmailController = TextEditingController();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String? _userRole;
  String? _userName;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _loadUserData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final role = await _authService.getUserRole();
      final userData = await _authService.getUserData();
      if (userData == null || role == null) {
        await _authService.signOut();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
          );
        }
        return;
      }
      setState(() {
        _userRole = role;
        _userName = '${userData['firstName']} ${userData['lastName']}';
        _isLoading = false;
      });
    } catch (e) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    }
  }

  Future<void> _addBook() async {
    if (_titleController.text.isNotEmpty &&
        _categoryController.text.isNotEmpty &&
        _authorController.text.isNotEmpty &&
        _linkController.text.isNotEmpty) {
      try {
        DatabaseReference newBookRef = _database.child('books').push();
        await newBookRef.set({
          'title': _titleController.text,
          'category': _categoryController.text,
          'author': _authorController.text,
          'link': _linkController.text,
          'createdAt': ServerValue.timestamp,
        });
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Book added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding book: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields')),
      );
    }
  }

  Future<void> _removeBook(String bookId) async {
    try {
      await _database.child('books').child(bookId).remove();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Book removed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing book: $e')),
      );
    }
  }

  Future<void> _promoteToAdmin() async {
    String email = _adminEmailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an email')),
      );
      return;
    }
    try {
      DatabaseReference usersRef = _database.child('users');
      DataSnapshot snapshot = await usersRef.get();
      String? userId;
      if (snapshot.exists) {
        Map<dynamic, dynamic> users = snapshot.value as Map<dynamic, dynamic>;
        users.forEach((key, value) {
          if (value['email'] == email) userId = key;
        });
      }
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User with email $email not found')),
        );
        return;
      }
      await usersRef.child(userId!).update({'role': 'admin'});
      _adminEmailController.clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email has been promoted to admin')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error promoting user: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPendingUsers() async {
    try {
      DataSnapshot snapshot = await _database.child('users').get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> users = snapshot.value as Map<dynamic, dynamic>;
        return users.entries
            .where((entry) => entry.value['status'] == 'pending')
            .map((entry) => {
                  'uid': entry.key,
                  'email': entry.value['email'],
                  'firstName': entry.value['firstName'],
                  'lastName': entry.value['lastName'],
                })
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching pending users: $e');
      return [];
    }
  }

  Future<void> _updateUserStatus(String uid, String status) async {
    try {
      await _database.child('users').child(uid).update({'status': status});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User $status successfully')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user status: $e')),
      );
    }
  }

  void _navigateToBookDetails({
    required String title,
    required String category,
    required String author,
    required String link,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => BookDetailsScreen(
          title: title,
          category: category,
          author: author,
          link: link,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _clearForm() {
    _titleController.clear();
    _categoryController.clear();
    _authorController.clear();
    _linkController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scouts',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2F4156),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                '$_userName ($_userRole)',
                style: const TextStyle(
                  color: Color(0xFFC8D9E6),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFFFFFF)),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
            },
          ),
        ],
      ),
      floatingActionButton: _userRole == 'admin'
          ? FloatingActionButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _buildAdminFormDialog(),
              ),
              backgroundColor: const Color(0xFF5C7C8D),
              child: const Icon(Icons.add, color: Color(0xFFFFFFFF)),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2F4156),
              Color(0xFFF5EFE8),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore Your Library',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFFFFF),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: const Offset(2, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Discover new books and manage your collection',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFFC8D9E6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Search books...',
                            hintStyle: const TextStyle(color: Color(0xFF5C7C8D)),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF2F4156)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_userRole == 'admin') ...[
                        _buildSectionTitle('Admin Actions'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildActionButton(
                              label: 'Promote to Admin',
                              icon: Icons.person_add,
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => _buildPromoteDialog(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Pending Users'),
                        const SizedBox(height: 16),
                        _buildPendingUsersList(),
                      ],
                      _buildSectionTitle('New Collection'),
                      const SizedBox(height: 16),
                      _buildBookCarousel(),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Management'),
                      const SizedBox(height: 16),
                      _buildBookList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2F4156),
          shadows: [
            Shadow(
              color: Colors.black12,
              offset: Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF5C7C8D),
                Color(0xFF2F4156),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFFFFFFF), size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminFormDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add New Book',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2F4156),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(_titleController, 'Title', Icons.title, textDirection: TextDirection.rtl),
            const SizedBox(height: 12),
            _buildTextField(_categoryController, 'Category', Icons.category),
            const SizedBox(height: 12),
            _buildTextField(_authorController, 'Author', Icons.person),
            const SizedBox(height: 12),
            _buildTextField(_linkController, 'Link', Icons.link, keyboardType: TextInputType.url),
            const SizedBox(height: 24),
            ScaleTransition(
              scale: _scaleAnimation,
              child: ElevatedButton(
                onPressed: () {
                  _addBook();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C7C8D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                child: const Text(
                  'Add Book',
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextDirection textDirection = TextDirection.ltr,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      textDirection: textDirection,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF5C7C8D)),
        prefixIcon: Icon(icon, color: const Color(0xFF2F4156)),
        filled: true,
        fillColor: const Color(0xFFC8D9E6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5C7C8D)),
        ),
      ),
    );
  }

  Widget _buildPromoteDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Promote User to Admin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2F4156),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(_adminEmailController, 'User Email', Icons.email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF5C7C8D), fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: ElevatedButton(
                    onPressed: () {
                      _promoteToAdmin();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C7C8D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Promote',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingUsersList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPendingUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No pending users'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            var user = snapshot.data![index];
            return ListTile(
              title: Text(
                '${user['firstName']} ${user['lastName']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F4156),
                ),
              ),
              subtitle: Text(user['email']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _updateUserStatus(user['uid'], 'approved'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _updateUserStatus(user['uid'], 'rejected'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookCarousel() {
    return Container(
      height: 200,
      child: StreamBuilder<DatabaseEvent>(
        stream: _database.child('books').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text('No books available'));
          }

          Map<dynamic, dynamic> books = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          var filteredBooks = books.entries
              .where((entry) => entry.value['title'].toString().toLowerCase().contains(searchQuery))
              .toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filteredBooks.length,
            itemBuilder: (context, index) {
              var book = filteredBooks[index].value;
              return ScaleTransition(
                scale: _scaleAnimation,
                child: BookCard(
                  title: book['title'],
                  category: book['category'],
                  link: book['link'] ?? 'No link',
                  onTap: () => _navigateToBookDetails(
                    title: book['title'],
                    category: book['category'],
                    author: book['author'],
                    link: book['link'] ?? 'No link',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _database.child('books').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('No books available'));
        }

        Map<dynamic, dynamic> books = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        var filteredBooks = books.entries
            .where((entry) => entry.value['title'].toString().toLowerCase().contains(searchQuery))
            .toList()
          ..sort((a, b) => (b.value['createdAt'] ?? 0).compareTo(a.value['createdAt'] ?? 0));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredBooks.length,
          itemBuilder: (context, index) {
            var book = filteredBooks[index].value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 600 + (index * 100)),
                curve: Curves.easeOut,
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: BookTile(
                        title: book['title'],
                        author: book['author'],
                        link: book['link'] ?? 'No link',
                        onRemove: _userRole == 'admin' ? () => _removeBook(filteredBooks[index].key) : null,
                        onTap: () => _navigateToBookDetails(
                          title: book['title'],
                          category: book['category'],
                          author: book['author'],
                          link: book['link'] ?? 'No link',
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class BookCard extends StatelessWidget {
  final String title;
  final String category;
  final String link;
  final VoidCallback? onTap;

  const BookCard({required this.title, required this.category, required this.link, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFC8D9E6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.book,
              size: 48,
              color: Color(0xFF2F4156),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF2F4156),
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              category,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF5C7C8D),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class BookTile extends StatelessWidget {
  final String title;
  final String author;
  final String link;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const BookTile({
    required this.title,
    required this.author,
    required this.link,
    this.onRemove,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFC8D9E6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF2F4156),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.book,
            color: Color(0xFFFFFFFF),
            size: 32,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF2F4156),
          ),
          textDirection: TextDirection.rtl,
        ),
        subtitle: Text(
          author,
          style: const TextStyle(
            color: Color(0xFF5C7C8D),
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 28),
                onPressed: onRemove,
              ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: Color(0xFF5C7C8D),
            ),
          ],
        ),
      ),
    );
  }
}