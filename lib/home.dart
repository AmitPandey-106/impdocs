import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:impdocument/login.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class NewHomePage extends StatefulWidget {
  const NewHomePage({super.key, required this.title});

  final String title;

  @override
  State<NewHomePage> createState() => _NewHomePageState();
}

class _NewHomePageState extends State<NewHomePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: const TabBarView(
          children: [
            UploadAssignmentsPage(),
            MyAssignmentsPage(),
            UserProfile(),
          ],
        ),
        bottomNavigationBar: const TabBar(
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          tabs: [
            Tab(icon: Icon(Icons.upload_file), text: 'Upload'),
            Tab(icon: Icon(Icons.assignment), text: 'My Assignments'),
            Tab(icon: Icon(Icons.person), text: 'My Profile',)
          ],
        ),
      ),
    );
  }
}

class UploadAssignmentsPage extends StatefulWidget {
  const UploadAssignmentsPage({super.key});

  @override
  State<UploadAssignmentsPage> createState() => _UploadAssignmentsPageState();
}

class _UploadAssignmentsPageState extends State<UploadAssignmentsPage> {
  String? selectedYear;
  String? selectedStream;
  String? selectedDivision;
  String? selectedSemester;
  String? pdfFileName;
  String? pdfFilePath;

  final List<String> years = ['FE', 'SE', 'TE', 'BE'];
  final List<String> streams = ['IT', 'CS', 'AIDS'];
  final List<String> divisions = ['A', 'B', 'C'];
  final List<String> semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];

  // Your Cloudinary configuration
  final String cloudName = "amitcloud2";
  final String apiKey = "652977423445947";
  final String apiSecret = "LpuWmqjtgNqenThLlF1zQuv4uzg";

  bool isLoading = false;

  Future<void> uploadToCloudinary() async {
    setState(() {
      isLoading = true; // Show loading indicator
    });

    if (pdfFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF to upload.')),
      );
      return;
    }

    try {
      // Step 1: Prepare the request
      final Uri uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");

      final http.MultipartRequest request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = 'amitbook'; // Use your upload preset name
      request.fields['cloud_name'] = cloudName;    // Your Cloudinary cloud name
      request.fields['folder'] = 'my_pdfs';        // Optional: Specify a folder if needed
      request.files.add(await http.MultipartFile.fromPath('file', pdfFilePath!));

      final http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        final String responseData = await response.stream.bytesToString();
        final Map<String, dynamic> jsonData = json.decode(responseData);
        final String pdfUrl = jsonData['secure_url'];
        saveAssignmentToFirebase(pdfUrl);
      } else {
        final String errorResponse = await response.stream.bytesToString();
        print('Cloudinary Error: $errorResponse');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> saveAssignmentToFirebase(String pdfUrl) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');
    String trimmedEmail = userEmail!.split('@')[0];

    try {
      setState(() {
        isLoading = true; // Show loading indicator
      });
      // Get reference to Firebase Realtime Database
      DatabaseReference databaseRef = FirebaseDatabase.instance.ref("assignments");

      DatabaseReference newAssignmentRef = databaseRef.child(trimmedEmail).push();

      // Push the data into the database
      await newAssignmentRef.set({
        'year': selectedYear,
        'stream': selectedStream,
        'division': selectedDivision,
        'semester': selectedSemester,
        'pdfUrl': pdfUrl,
        'pdfName': pdfFileName,
        'uploadedAt': DateTime.now().toString(),
        'status':'waiting',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assignment uploaded successfully!')),
      );

      // Clear fields after successful upload
      setState(() {
        selectedYear = null;
        selectedStream = null;
        selectedDivision = null;
        selectedSemester = null;
        pdfFileName = null;
        pdfFilePath = null;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false; // Hide loading indicator
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving to database: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Upload Assignment",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                buildDropdown("Select Year", years, selectedYear, (value) {
                  setState(() {
                    selectedYear = value;
                  });
                }),

                buildDropdown("Select Stream", streams, selectedStream, (value) {
                  setState(() {
                    selectedStream = value;
                  });
                }),

                buildDropdown("Select Division", divisions, selectedDivision, (value) {
                  setState(() {
                    selectedDivision = value;
                  });
                }),

                buildDropdown("Select Semester", semesters, selectedSemester, (value) {
                  setState(() {
                    selectedSemester = value;
                  });
                }),

                const SizedBox(height: 20),

                Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );

                      if (result != null) {
                        setState(() {
                          pdfFileName = result.files.single.name;
                          pdfFilePath = result.files.single.path;
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Select PDF"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                pdfFileName != null
                    ? Center(
                  child: Text(
                    "Selected File: $pdfFileName",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.blue),
                  ),
                )
                    : const Center(
                  child: Text(
                    "No PDF Selected",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: () async {
                      await uploadToCloudinary();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      "Upload Assignment",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildDropdown(String hint, List<String> items, String? selectedItem, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: selectedItem,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}


class MyAssignmentsPage extends StatefulWidget {
  const MyAssignmentsPage({super.key});

  @override
  State<MyAssignmentsPage> createState() => _MyAssignmentsPageState();
}

class _MyAssignmentsPageState extends State<MyAssignmentsPage> {
  final DatabaseReference databaseRef = FirebaseDatabase.instance.ref("assignments");
  List<Map<String, dynamic>> assignments = [];
  bool isLoading = true;
  String? userRole;
  double downloadProgress = 0.0;

  // Future<bool> requestPermission(BuildContext context) async {
  //   var status = await Permission.storage.request();
  //
  //   if (status.isGranted) {
  //     print("Storage permission granted.");
  //     return true;
  //   } else if (status.isDenied) {
  //     // Show pop-up if permission is denied
  //     bool shouldAskAgain = await showDialog(
  //       context: context,
  //       builder: (BuildContext context) {
  //         return AlertDialog(
  //           title: Text("Permission Required"),
  //           content: Text("This app needs storage permission to download PDFs."),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(context).pop(false), // Cancel
  //               child: Text("Cancel"),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.of(context).pop(true); // Request again
  //               },
  //               child: Text("Allow"),
  //             ),
  //           ],
  //         );
  //       },
  //     );
  //
  //     if (shouldAskAgain == true) {
  //       return await requestPermission(context); // Request again
  //     }
  //   } else if (status.isPermanentlyDenied) {
  //     // Open app settings if permanently denied
  //     openAppSettings();
  //   }
  //
  //   return false;
  // }


  Future<void> fetchAssignments() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('userEmail');
    userRole = prefs.getString('role');

    try {
      if (userRole == 'admin') {
        await fetchAllAssignments();
      } else {
        await fetchUserAssignments(userEmail);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching assignments: $e')),
      );
    }
  }

  Future<void> fetchUserAssignments(String? userEmail) async {
    if (userEmail == null) return;
    String trimmedEmail = userEmail.split('@')[0];
    final DataSnapshot snapshot = await databaseRef.child(trimmedEmail).get();

    if (snapshot.exists) {
      final List<Map<String, dynamic>> fetchedAssignments = [];
      for (var child in snapshot.children) {
        fetchedAssignments.add(_mapSnapshotToAssignment(child));
      }
      setState(() {
        assignments = fetchedAssignments;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchAllAssignments() async {
    final DataSnapshot snapshot = await databaseRef.get();
    if (snapshot.exists) {
      final List<Map<String, dynamic>> fetchedAssignments = [];
      for (var user in snapshot.children) {
        for (var child in user.children) {
          fetchedAssignments.add(_mapSnapshotToAssignment(child));
        }
      }
      setState(() {
        assignments = fetchedAssignments;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Map<String, dynamic> _mapSnapshotToAssignment(DataSnapshot child) {
    return {
      'year': child.child('year').value,
      'stream': child.child('stream').value,
      'division': child.child('division').value,
      'pdfUrl': child.child('pdfUrl').value,
      'pdfName': child.child('pdfName').value,
      'uploadedAt': child.child('uploadedAt').value,
    };
  }

  @override
  void initState() {
    super.initState();
    fetchAssignments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : assignments.isEmpty
          ? const Center(child: Text("No assignments uploaded yet."))
          : ListView.builder(
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    assignment['pdfName'] ?? 'Unknown PDF',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Year: ${assignment['year']}", style: const TextStyle(fontSize: 14)),
                      Text("Stream: ${assignment['stream']}", style: const TextStyle(fontSize: 14)),
                      Text("Division: ${assignment['division']}", style: const TextStyle(fontSize: 14)),
                      Text("Uploaded At: ${assignment['uploadedAt']}", style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),

                        onPressed: () => _viewPDF(context, assignment['pdfUrl']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () async {
                           // Pass context
                            _downloadPDF(assignment['pdfUrl']);

                        },
                      ),

                    ],
                  ),
                ),
                if (downloadProgress > 0 && downloadProgress < 100)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        LinearProgressIndicator(value: downloadProgress / 100),
                        Text("${downloadProgress.toStringAsFixed(1)}% downloaded"),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _viewPDF(BuildContext context, String? pdfUrl) {
    if (pdfUrl != null && pdfUrl.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PDFViewerPage(pdfUrl: pdfUrl)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid PDF URL.')),
      );
    }
  }

  void _downloadPDF(String? pdfUrl) async {
    if (pdfUrl != null && pdfUrl.isNotEmpty) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting Download...')),
        );

        Dio dio = Dio();
        String fileName = pdfUrl.split('/').last;

        Directory? directory = await getExternalStorageDirectory();
        if (directory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage access issue.')),
          );
          return;
        }

        String filePath = "${directory.path}/$fileName";

        await dio.download(
          pdfUrl,
          filePath,
          options: Options(
            headers: {
              "Authorization": "Bearer YOUR_ACCESS_TOKEN", // Add authentication if needed
            },
          ),
          onReceiveProgress: (received, total) {
            if (total != -1) {
              double progress = (received / total) * 100;
              setState(() {
                downloadProgress = progress;
              });
            }
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download Completed: $fileName')),
        );

        setState(() {
          downloadProgress = 0.0;
        });

        // Open the PDF file
        OpenFile.open(filePath);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download Failed: $e')),
        );
        setState(() {
          downloadProgress = 0.0;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid PDF URL.')),
      );
    }
  }


}

class PDFViewerPage extends StatelessWidget {
  final String pdfUrl;

  const PDFViewerPage({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("View PDF")),
      body: PDFView(
        filePath: pdfUrl,
      ),
    );
  }
}




class UserProfile extends StatelessWidget {
  const UserProfile({super.key});

  // Method to retrieve email from SharedPreferences
  Future<String?> getUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userEmail');
  }

  // Method to fetch user data from Firebase Realtime Database
  Future<Map<String, String>?> fetchUserData(String email) async {
    DatabaseReference ref = FirebaseDatabase.instance.ref('users');
    final snapshot = await ref.get();

    if (snapshot.exists) {
      for (var user in snapshot.children) {
        final userEmail = user.child('email').value.toString();
        if (userEmail == email) {
          final userName = user.child('name').value.toString();
          return {'name': userName, 'email': userEmail};
        }
      }
    }
    return null; // Return null if no matching email is found
  }

  // Method to handle logout
  Future<void> logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userEmail'); // Clear stored email
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    ); // Navigate to LoginPage
  }

  // Method to show logout confirmation dialog
  void showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                logout(context); // Perform logout
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => showLogoutDialog(context), // Handle logout
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: getUserEmail(),
        builder: (BuildContext context, AsyncSnapshot<String?> emailSnapshot) {
          if (emailSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (emailSnapshot.hasError || !emailSnapshot.hasData || emailSnapshot.data == null) {
            return const Center(child: Text("No user email found in SharedPreferences."));
          } else {
            final email = emailSnapshot.data!;
            return FutureBuilder<Map<String, String>?>(
              future: fetchUserData(email),
              builder: (BuildContext context, AsyncSnapshot<Map<String, String>?> dataSnapshot) {
                if (dataSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (dataSnapshot.hasError || !dataSnapshot.hasData || dataSnapshot.data == null) {
                  return const Center(child: Text("User data not found in database."));
                } else {
                  final userData = dataSnapshot.data!;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Name: ${userData['name']}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Email: ${userData['email']}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
              },
            );
          }
        },
      ),
    );
  }
}

