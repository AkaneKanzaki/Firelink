class AppLocalizations {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'home_new_project': 'New Project',
      'home_open_project': 'Open Project',
      'home_tutorial': 'Practice / Tutorial',
      'settings_theme': 'Theme',
      'settings_language': 'Language',
    },
    'id': {
      'home_new_project': 'Proyek Baru',
      'home_open_project': 'Buka Proyek',
      'home_tutorial': 'Latihan / Tutorial',
      'settings_theme': 'Tema',
      'settings_language': 'Bahasa',

      // Tutorial Selection Screen
      'Select Tutorial Level': 'Pilih Level Tutorial',
      'Campaign Mode': 'Mode Kampanye',
      'Complete levels to unlock more advanced scenarios.': 'Selesaikan level untuk membuka skenario yang lebih menantang.',
      'Level': 'Level',

      // Tutorial Levels
      'Level 1: Basic Connection': 'Level 1: Koneksi Dasar',
      'Learn how to add devices and connect them directly.': 'Pelajari cara menambahkan perangkat dan menghubungkannya secara langsung.',
      'Step 1: Drag and drop two PCs onto the glowing blueprints.': 'Langkah 1: Seret dan lepas dua PC ke atas cetak biru (blueprints) yang bersinar.',
      'Step 2: Open the Cable Palette, select the Crossover cable, and connect the two PCs together.': 'Langkah 2: Buka Palet Kabel, pilih kabel Crossover, dan hubungkan kedua PC tersebut.',
      
      'Level 2: Switch Connection': 'Level 2: Koneksi Switch',
      'Learn how to connect multiple PCs using a Switch.': 'Pelajari cara menghubungkan beberapa PC menggunakan sebuah Switch.',
      'Step 1: Place a Switch at the top, and two PCs below it.': 'Langkah 1: Letakkan sebuah Switch di bagian atas, dan dua PC di bawahnya.',
      'Step 2: Connect both PCs to the Switch using Straight-through cables.': 'Langkah 2: Hubungkan kedua PC ke Switch menggunakan kabel Straight-through.',
      
      'Level 3: Router Connection': 'Level 3: Koneksi Router',
      'Learn how to connect a Router to a Switch and a PC.': 'Pelajari cara menghubungkan sebuah Router ke Switch dan PC.',
      'Step 1: Place a Router, a Switch, and a PC in a vertical line.': 'Langkah 1: Letakkan Router, Switch, dan PC dalam garis vertikal.',
      'Step 2: Connect the PC to the Switch, and the Switch to the Router using Straight-through cables.': 'Langkah 2: Hubungkan PC ke Switch, dan Switch ke Router menggunakan kabel Straight-through.',
      
      'Level 4: Basic IP Config': 'Level 4: Konfigurasi IP Dasar',
      'Learn how to configure an IP address on a PC.': 'Pelajari cara melakukan konfigurasi alamat IP pada PC.',
      'Step 1: Place a single PC on the workspace.': 'Langkah 1: Letakkan sebuah PC di ruang kerja.',
      'Step 2: Tap the PC, open its Interfaces, and set its IP address to 192.168.1.10': 'Langkah 2: Ketuk PC, buka menu Interfaces, dan atur alamat IP-nya menjadi 192.168.1.10',
      
      'Level 5: DHCP Config': 'Level 5: Konfigurasi DHCP',
      'Learn how to enable a DHCP server on a Router and a DHCP client on a PC.': 'Pelajari cara mengaktifkan DHCP Server pada Router dan DHCP Client pada PC.',
      'Step 1: Place a Router and a PC, then connect them using a Crossover cable.': 'Langkah 1: Letakkan Router dan PC, lalu hubungkan menggunakan kabel Crossover.',
      'Step 2: Configure the Router\'s interface (Tap Router -> Interfaces) and set IP to 192.168.1.1': 'Langkah 2: Konfigurasi antarmuka Router (Ketuk Router -> Interfaces) dan atur IP menjadi 192.168.1.1',
      'Step 3: Configure the Router to act as a DHCP server (Tap Router -> DHCP Server -> Enable).': 'Langkah 3: Konfigurasi Router agar bertindak sebagai DHCP server (Ketuk Router -> DHCP Server -> Enable).',
      'Step 4: Enable DHCP Client on the PC (Tap PC -> Interfaces -> DHCP Client).': 'Langkah 4: Aktifkan DHCP Client pada PC (Ketuk PC -> Interfaces -> DHCP Client).'
    },
  };

  static String get(String key, String localeCode) {
    return _localizedValues[localeCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}
