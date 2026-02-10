# KhonoBuzz App - User Journey Navigation Map

## 🚀 Complete User Flow Through Application Screens

This document maps out the complete user journey through the KhonoBuzz Flutter application, showing screen names, script files, and navigation paths.

---

## 📱 **STARTING POINTS**

### 1. **Welcome Screen** (`welcome_screen.dart`)
- **Entry Point**: App launch (if configured)
- **Navigation**: "GET STARTED" → Landing Screen
- **Purpose**: Initial welcome with animated quotes

### 2. **Landing Screen** (`landing_screen.dart`) 🏠
- **Main Entry Point**: App launch
- **Navigation**: "GET STARTED" → Auth Screen
- **Features**: 
  - KhonoBuzz logo animation
  - "GET STARTED" button (red)
  - Backend warm-up on button click

---

## 🔐 **AUTHENTICATION FLOW**

### 3. **Auth Screen** (`auth_screen.dart`) 🔑
**Navigation Options from Landing Screen:**
- **MICROSOFT LOGIN** → Main Screen (index 8) → Modules Screen (index 9)
- **MANUAL LOGIN** → Manual Login Screen
- **ONBOARD WITH US** → Onboarding Screen

**Authentication Methods:**
- Microsoft SSO (khonology.com accounts only)
- Manual email login
- New user onboarding

### 4. **Manual Login Screen** (`manual_login_screen.dart`) 📧
- **Navigation**: "CONFIRM" → Main Screen (index 8) → Modules Screen (index 9)
- **Error Handling**: 
  - Pending approval → Dialog message
  - Invalid email → Error dialog

### 5. **Onboarding Screen** (`onboarding_screen.dart`) 📝
- **Form Fields**: First Name, Surname, Email, Department, Designation
- **Navigation**: 
  - "CONFIRM" → Lobby Screen (for pending users)
  - "BACK" → Auth Screen
- **Validation**: Only @khonology.com emails allowed

### 6. **Lobby Screen** (`lobby_screen.dart`) ⏳
- **Purpose**: Waiting screen for pending approval
- **Features**: Animated rocket video, spinning discs
- **Navigation**: "Go Back" → Auth Screen

---

## 🏢 **MAIN APPLICATION (MainScreen)**

### **Main Screen Structure** (`main.dart`) 🗂️
**Side Menu Navigation with Role-Based Access:**

| Index | Screen | Script File | Access Level |
|-------|--------|-------------|--------------|
| 0 | Dashboard | `dashboard_screen.dart` | All Users |
| 1 | Resource Allocation | `resource_allocation_screen.dart` | All Users |
| 2 | Time Keeping | `time_keeping_screen.dart` | All Users |
| 3 | Project Data | `project_data_screen.dart` | All Users |
| 4 | Analytics | `analytics_screen.dart` | All Users |
| 5 | Profile | `profile_screen.dart` | All Users |
| 6 | User Management | `user_management_screen.dart` | **Admin Only** |
| 7 | Entity Management | `entity_management_screen.dart` | **Admin Only** |
| 8 | Module Access | `module_access_screen.dart` | **Admin Only** |
| 9 | **Modules** | `module_screen.dart` | **Default Landing** |
| 10 | Projects | `projects_screen.dart` | All Users |

---

## 🎯 **KEY SCREENS DETAILS**

### **Modules Screen** (`module_screen.dart`) 📦
**Primary landing screen for all authenticated users**
**Available Modules (based on user access):**

| Module | URL | Access Control |
|--------|-----|-----------------|
| Personal Development Hub | https://pdh-web-app.onrender.com | PDH Access |
| Resource & Capacity Skills Heatmap | https://resource-capacity-and-skills-heatmap.netlify.app/ | Skills Heatmap Access |
| Automated Recruitment Workflow | https://willowy-scone-c14f7c.netlify.app/ | Recruitment Access |
| Proposal & SOW Builder | https://proposals2025.netlify.app/ | SOW Builder Access |
| Deliverables & Sprint Sign-Off Hub | https://flow-space-1.onrender.com/ | Deliverables Access |

### **Admin-Only Screens:**
- **User Management** (`user_management_screen.dart`) - Manage user accounts
- **Entity Management** (`entity_management_screen.dart`) - Manage entities
- **Module Access** (`module_access_screen.dart`) - Assign module permissions

### **Staff Accessible Screens:**
- **Dashboard** (`dashboard_screen.dart`) - Main dashboard view
- **Resource Allocation** (`resource_allocation_screen.dart`) - Resource management
- **Time Keeping** (`time_keeping_screen.dart`) - Time tracking
- **Project Data** (`project_data_screen.dart`) - Project information
- **Analytics** (`analytics_screen.dart`) - Data analytics
- **Profile** (`profile_screen.dart`) - User profile management
- **Projects** (`projects_screen.dart`) - Project management

---

## 🔄 **COMPLETE USER JOURNEY PATHS**

### **New User Onboarding Path:**
```
Landing Screen → Auth Screen → Onboarding Screen → Lobby Screen → (Admin Approval) → Main Screen (Modules)
```

### **Existing User Login Path:**
```
Landing Screen → Auth Screen → (Microsoft/Manual Login) → Main Screen (Modules)
```

### **Admin User Path:**
```
Landing Screen → Auth Screen → Main Screen (Modules) → Access to all screens including admin functions
```

### **Staff User Path:**
```
Landing Screen → Auth Screen → Main Screen (Modules) → Limited access (no admin screens)
```

---

## 🚫 **ACCESS CONTROL NOTES**

- **Email Domain Restriction**: Only @khonology.com emails allowed
- **Role-Based Navigation**: Staff users redirected to Modules if accessing admin screens
- **Module Access**: Controlled via backend permissions
- **Pending Users**: Must wait for admin approval before accessing main app

---

## 🎨 **UI/UX FEATURES**

- **Consistent Theme**: Dark background with red accent color (#C10D00)
- **Animations**: Particle effects, button animations, loading states
- **Responsive Design**: Adaptive layouts for different screen sizes
- **Error Handling**: User-friendly dialogs and snack bars
- **Loading States**: Visual feedback during API calls

---

## 📊 **NAVIGATION SUMMARY**

**Total Active Screens**: 25
**Entry Points**: 2 (Welcome, Landing)
**Authentication Screens**: 4 (Auth, Manual Login, Onboarding, Lobby)
**Main App Screens**: 11 (via MainScreen navigation)
**Admin-Only**: 3 screens
**Staff Accessible**: 8 screens

**Default Landing**: All authenticated users land on Modules Screen (index 9)
**Security**: Role-based access control with automatic redirects

---

*This map represents the complete user journey through the KhonoBuzz application as of the current codebase version.*
