<?php
/**
 * Salin file ini menjadi `config.php` lalu isi nilainya.
 * (config.php masuk .gitignore — jangan pernah commit kredensial asli.)
 *
 * ------------------------------------------------------------------
 * PRODUKSI (shared hosting cPanel + MySQL):
 *   'dsn'  => 'mysql:host=localhost;dbname=NAMA_DB;charset=utf8mb4',
 *   'user' => 'user_db',
 *   'pass' => 'password_db',
 *
 * PRATINJAU LOKAL (tanpa MySQL, pakai SQLite):
 *   'dsn'  => 'sqlite:' . __DIR__ . '/inventaris.db',
 *   'user' => null, 'pass' => null,
 *   lalu: php -S localhost:8080 -t backend
 *   buka: http://localhost:8080/api.php?op=ping
 *
 * `api_key` = kunci bersama yang dikirim aplikasi lewat header X-Api-Key
 * (dart-define MYSQL_API_KEY). SANGAT DISARANKAN di hosting publik
 * supaya tidak sembarang orang bisa menulis data. Biarkan '' hanya
 * untuk uji coba lokal.
 *
 * `allow_origin` = asal (origin) web yang boleh memanggil API. '*' aman
 * bila API hanya dipakai aplikasi ini; isi mis. 'https://domainanda.com'
 * bila web dihosting di domain lain (CORS).
 */
return [
    'dsn' => 'mysql:host=localhost;dbname=spek_inventaris;charset=utf8mb4',
    'user' => 'GANTI_USER_DB',
    'pass' => 'GANTI_PASSWORD_DB',
    'api_key' => '',
    'allow_origin' => '*',
];
