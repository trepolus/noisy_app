# 🧭 Noisy App – City Exploration Game

A location-based Flutter app where users explore the city on foot.  
As you approach real-world points of interest (POIs), white noise intensifies...  
Get close enough, and a story about the location is revealed ✨

---

## 🧩 Features

- 📍 Live user location tracking
- 🗺️ Google Maps integration
- 🔊 Sound proximity triggers
- 🦄 Fun visual feedback (emoji & animations)
- 🤖 AI-generated stories about POIs (OpenAI)
- 🎨 Minimal UI with animated blobs for POI distance

---

## 🚀 Getting Started

1. **Clone this repo**
2. **Install Flutter packages**
   ```bash
   flutter pub get
   ```

3. **Add your sound asset**
    - Place your sound file in `assets/sounds/leiwand.m4a`
    - Or convert to `.mp3` if needed

4. **Configure OpenAI API key (soon)**
    - Create a `.env` or use secure method (coming soon)

5. **Run on iPhone (or Android)**
   ```bash
   flutter run
   ```

---

## 🛠 Tech Stack

- Flutter + Dart
- Google Maps Flutter
- Geolocator for GPS
- Audioplayers for sound
- OpenAI API (for story generation)

---

## 👤 Author

Built with ❤️ in Berlin  
Vision & Code by Lucas – with help of AI, and magic ✨

```
 scaffold the `assets/pois/pois.json` file next for your custom landmarks?