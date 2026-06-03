#!/bin/bash

# POS Flutter 應用程式啟動腳本

echo "🚀 Starting POS Flutter Application..."

# 檢查 Flutter 是否安裝
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# 檢查依賴
echo "📦 Checking dependencies..."
if [ ! -d ".dart_tool" ]; then
    echo "Installing dependencies..."
    flutter pub get
fi

# 選擇平台
echo ""
echo "Select platform to run:"
echo "1) Chrome (Web)"
echo "2) macOS (Desktop)"
echo "3) Android Emulator"
echo "4) iOS Simulator"
echo ""
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo "🌐 Running on Chrome..."
        flutter run -d chrome
        ;;
    2)
        echo "💻 Running on macOS..."
        flutter run -d macos
        ;;
    3)
        echo "📱 Running on Android..."
        flutter run -d android
        ;;
    4)
        echo "📱 Running on iOS..."
        flutter run -d ios
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac
