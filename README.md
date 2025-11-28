# 📚 CollabLearn: A Comprehensive LMS for Collaborative Learning

**CollabLearn** is a robust Learning Management System (LMS) built with Flutter and Firebase, designed to facilitate seamless interaction between instructors and students at **IIT Ropar**. It offers a comprehensive suite of features including class management, attendance tracking via QR codes, assignment submission, grading, quizzes, and real-time study group chats.

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![Cloudinary](https://img.shields.io/badge/Cloudinary-3448C5?style=for-the-badge&logo=cloudinary&logoColor=white)

---

## 🚀 Key Features

### 🎓 For Everyone
* **Secure Authentication:**
    * Email/Password login restricted to the `@iitrpr.ac.in` domain.
    * Google Sign-In integration.
    * Strict email verification enforcement.
    * Role-based access control (Instructor vs. Student).
* **Profile Management:** Edit profile details and update profile pictures.
* **Theme Support:** Toggle between Light and Dark modes.

### 👨‍🏫 For Instructors
* **Class Management:** Create new classes, archive old ones, and add co-instructors.
* **Student Management:** View enrolled students, manage rosters, and access individual student reports.
* **Attendance System:** Generate dynamic QR codes for sessions and view real-time reports.
* **Assignments:**
    * Create assignments with attachments (PDF, PPT, Images) via Cloudinary.
    * Review submissions, grade work, and provide feedback.
* **Quizzes:** Create timed quizzes with auto-submission logic.
* **Communication:** Post announcements and share study materials.

### 👩‍🎓 For Students
* **Dashboard:** View enrolled classes and a dynamic **Performance Tracker** (Attendance %, Quiz Averages, Assignment Completion).
* **Attendance:** Mark attendance instantly by scanning the instructor's QR code.
* **Assignments:** Submit work by uploading files directly from the app.
* **Quizzes:** Take timed quizzes with multiple-choice questions.
* **Collaboration:**
    * **Doubt Polls:** Ask questions, upvote doubts, and reply to peers.
    * **Study Groups:** Create groups, invite peers, and chat in real-time with file sharing.

---

## 🛠️ Technology Stack

| Component | Technology |
| :--- | :--- |
| **Frontend** | Flutter (Dart) |
| **Backend** | Firebase (Authentication, Firestore Database) |
| **Storage** | Cloudinary (File & Image Storage) |
| **State Management** | Native `setState` & `FutureBuilder`/`StreamBuilder` |

---

## 📸 Screenshots

| Login Screen | Dashboard | QR Scan | Quiz Page |
|:---:|:---:|:---:|:---:|
| <img src="path/to/login.png" width="200"> | <img src="path/to/dashboard.png" width="200"> | <img src="path/to/qr.png" width="200"> | <img src="path/to/quiz.png" width="200"> |


---

## 🚀 Getting Started

Follow these instructions to set up the project locally.

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
* A **Firebase** Account.
* A **Cloudinary** Account.

### Installation

1.  **Clone the Repository**
    ```bash
    git clone [https://github.com/yourusername/collablearn.git](https://github.com/yourusername/collablearn.git)
    cd collablearn
    ```

2.  **Install Dependencies**
    ```bash
    flutter pub get
    ```

### Configuration

#### 1. Firebase Setup
1.  Create a project in the [Firebase Console](https://console.firebase.google.com/).
2.  Enable **Authentication** (Email/Password & Google).
3.  Create a **Firestore Database**.
4.  Configure Android and iOS apps:
    * **Android:** Download `google-services.json` and place it in `android/app/`.
    * **iOS:** Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
    * *(Note: Ensure your project ID matches `collablearn-cf7a5` or regenerate configuration using `flutterfire configure`).*

#### 2. Cloudinary Setup
1.  Sign up for [Cloudinary](https://cloudinary.com/).
2.  Get your **Cloud Name** and **Upload Preset**.
3.  Update the constants in the following files:
    * `lib/create_assignment_page.dart`
    * `lib/upload_material_page.dart`
    * `lib/assignment_detail_page.dart`
    * `lib/study_group_chat_page.dart`

    ```dart
    const String _CLOUD_NAME = 'your_cloud_name';
    const String _UPLOAD_PRESET = 'your_upload_preset';
    ```

### 🔐 Security Rules & Indexes

**Firestore Indexes:**
The app performs complex queries (e.g., sorting assignments by date). Monitor your debug console while navigating the app; Firestore will provide links to create necessary composite indexes. Click the links in the console to build them automatically.

**Security Rules (Recommended):**
Ensure your Firestore rules strictly control access:
* **Users:** Read/write own data only.
* **Classes:** Instructors write; Students read.
* **Grades:** Only instructors can write to the `score` field.

### 📱 iOS Specific Setup

To build for iOS, configure `ios/Runner/Info.plist`:

1.  Add `NSCameraUsageDescription` (For QR scanning).
2.  Add `NSPhotoLibraryUsageDescription` (For file uploads).
3.  Add `CFBundleURLTypes` for Google Sign-In (using the reversed client ID).

---

## 🏃 Run the App

```bash
flutter run

