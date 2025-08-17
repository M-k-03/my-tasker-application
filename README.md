# 📱 My Tasker Application

A simple and lightweight utility app built with **Flutter** to help you manage product entries with ease.  

## ✨ Features
- ➕ **Add Products** with a date for easy tracking  
- 📝 **Edit / Delete** existing products  
- 👀 **View all entries** in a clean list  
- 🎨 Simple & clean UI for productivity  

---

## 🚀 Setup Instructions

### 1. Clone the repository
```bash
git clone https://github.com/your-username/my-tasker-application.git
cd my-tasker-application
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Firebase Setup
This project uses **Firebase** for backend services.  

1. Go to [Firebase Console](https://console.firebase.google.com/)  
2. Create a new project (or use existing one)  
3. Download the `google-services.json` (for Android) and `GoogleService-Info.plist` (for iOS)  
4. Place them in:
   - `android/app/google-services.json`  
   - `ios/Runner/GoogleService-Info.plist`  

⚠️ **Note**: These files are ignored in `.gitignore` for security reasons. You must add your own.

### 4. Run the application
```bash
flutter run
```

---

## 🛠 Tech Stack
- [Flutter](https://flutter.dev/) – Cross-platform UI toolkit  
- [Firebase](https://firebase.google.com/) – Backend services (Auth, DB, etc.)  

---

## 📄 License
This project is licensed under the **MIT License** – see the [LICENSE](LICENSE) file for details.
