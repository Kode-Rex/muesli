# 🥣 Muesli

**A full-stack conference note-taking platform with iOS app and API backend**

Muesli combines a beautifully crafted SwiftUI iOS app with a production-ready Node.js API for comprehensive conference note-taking, audio transcription, and session management. The platform features an elegant, dark-themed interface inspired by modern productivity apps.

## ✨ Features

### 📝 **Smart Note Management**
- Create and organize conference notes by session
- Rich content support with structured formatting (headers, bullets, sub-bullets)
- Real-time editing with live preview
- Automatic timestamping and date organization

### 🗂️ **Archive System**
- Archive completed sessions to keep your main screen focused
- Dedicated archive view for accessing historical notes
- Non-destructive archiving - easily restore when needed

### 🎯 **Conference-Focused UX**
- Session types: Meetings, Sessions, General Notes
- Conference name tracking
- Clean, distraction-free interface optimized for conference environments

### 🔧 **Advanced Actions**
- **Extract Personal Notes**: AI-powered extraction of your action items and key takeaways
- **Audio Transcription**: Real-time and batch audio transcription via Deepgram API
- **View Transcripts**: Access full session transcripts when available
- **Quick Copy**: One-tap copying of notes with haptic feedback
- **Title Editing**: Rename sessions on the fly

### 🌐 **API Backend**
- **Production-Ready**: Dockerized Node.js API with comprehensive testing
- **Audio Processing**: Batch and real-time transcription via Deepgram
- **Security**: Rate limiting, CORS, input validation, and authentication
- **Monitoring**: Health checks, structured logging, and performance metrics
- **CI/CD**: Automated testing with 36 tests and coverage reporting

### 🎨 **Beautiful Design**
- Native iOS dark theme
- Smooth animations and transitions
- Context menus and popovers for intuitive interactions
- Typography optimized for readability

### 🛠️ **Developer Features**
- **Professional Logging**: Structured logging with `os.log` for debugging and monitoring
- **Performance Monitoring**: Real-time performance metrics and memory usage tracking
- **Automated Code Quality**: SwiftLint integration with 40+ rules for consistent code style
- **Modular Architecture**: Reusable components following iOS best practices

## 📱 Screenshots

*Coming soon - the app features a sleek dark interface with organized note cards, contextual menus, and clean typography.*

## 🚀 Getting Started

### Prerequisites
- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/muesli.git
   cd muesli
   ```

2. **Setup API Backend** (optional for full functionality)
   ```bash
   cd src/api
   cp .env.example .env
   # Edit .env with your Deepgram API key
   npm install
   npm start
   ```

3. **Open iOS App in Xcode**
   ```bash
   open src/mobile/Muesli.xcodeproj
   ```

4. **Build and Run**
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

## 🏗️ Architecture

Muesli is a full-stack platform with clean separation between client and server:

### **📱 iOS App (SwiftUI)**
- **SwiftUI** for declarative UI
- **SwiftData** for local data persistence
- **MVVM-inspired** architecture with SwiftUI's native state management
- **Modular design** with separated views and reusable components

### **🌐 API Backend (Node.js)**
- **Express.js** RESTful API with WebSocket support
- **Deepgram** integration for audio transcription
- **Dockerized** deployment with multi-stage builds
- **Comprehensive testing** with Jest (36 tests, 17% coverage)

### Project Structure

```
src/
├── mobile/                     # iOS App
│   ├── Muesli/
│   │   ├── Models/
│   │   │   ├── Note.swift           # Core data model
│   │   │   └── SampleData.swift     # Demo content
│   │   ├── Views/
│   │   │   ├── SimpleMainView.swift      # Main dashboard
│   │   │   ├── SimpleNoteDetailView.swift # Note editing
│   │   │   ├── SimpleArchiveView.swift   # Archived notes
│   │   │   └── TranscriptView.swift      # Transcript viewer
│   │   └── MuesliApp.swift         # App entry point
│   ├── MuesliTests/                # Unit tests
│   └── MuesliUITests/              # UI tests
└── api/                        # Backend API
    ├── src/
    │   ├── routes/                 # API endpoints
    │   ├── services/               # Business logic
    │   ├── middleware/             # Express middleware
    │   └── config/                 # Configuration
    ├── tests/
    │   ├── unit/                   # Unit tests
    │   └── integration/            # Integration tests
    ├── Dockerfile                  # Container build
    └── docker-compose.yml          # Orchestration
```

## 🛠️ Technologies Used

### **📱 iOS App**
- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Apple's latest data persistence framework
- **UIKit Integration** - For clipboard access and haptic feedback
- **Foundation** - Core utilities and date formatting
- **os.log** - Apple's unified logging system for professional debugging
- **SwiftLint** - Automated code quality and style enforcement

### **🌐 API Backend**
- **Node.js 18+** - JavaScript runtime
- **Express.js** - Web application framework
- **Deepgram** - AI-powered speech recognition
- **Jest** - Testing framework with 36 comprehensive tests
- **Winston** - Structured logging
- **Docker** - Containerization and deployment
- **GitHub Actions** - CI/CD pipeline

## 🎯 Roadmap

- [ ] **AI Integration**: Smart summaries and action item extraction
- [ ] **Cloud Sync**: iCloud integration for cross-device access
- [ ] **Export Features**: PDF and Markdown export
- [ ] **Search**: Full-text search across all notes
- [ ] **Tags & Categories**: Enhanced organization
- [ ] **Collaboration**: Share notes with colleagues
- [ ] **Audio Integration**: Voice recording and transcription

## 🤝 Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by the clean design principles of modern productivity apps
- Built with ❤️ for the conference-going community
- Special thanks to the SwiftUI community for inspiration and best practices

## 📞 Contact

Project Link: [https://github.com/Kode-Rex/muesli](https://github.com/Kode-Rex/muesli)

---

*Make for a better conference experience*