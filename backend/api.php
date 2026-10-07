<?php
/**
 * API CRUD Inventaris — dipakai aplikasi Flutter (web & APK) sebagai
 * pengganti Supabase. Satu file, tanpa framework.
 *
 * Kontrak (semua respons JSON: {"ok":true,...} atau {"ok":false,"error":...}):
 *
 *   op=ping     -> cek koneksi & konfigurasi
 *   op=rev      -> nomor revisi + jumlah baris (dipolling tiap 5 detik;
 *                  klien hanya mengunduh data ulang bila berubah)
 *   op=migrate  -> buat tabel dari schema.sql / schema.sqlite.sql (idempoten)
 *   op=select   -> table, columns[], order{by,desc}, where[], limit
 *   op=insert   -> table, rows[], returning?
 *   op=update   -> table, set{}, where[]        (WHERE kosong ditolak)
 *   op=delete   -> table, where[]               (WHERE kosong ditolak)
 *   op=upsert   -> table, rows[], on_conflict   (tulis-per-baris, transaksi)
 *
 * where[] = [{"col":"id","op":"=","value":1}] dengan op: = | != | IN
 *
 * Keamanan: nama tabel & kolom hanya boleh dari whitelist (schema()),
 * semua nilai lewat prepared statement, dan bila config.php mengisi
 * `api_key` maka request wajib menyertakan header X-Api-Key.
 */

declare(strict_types=1);

// ---------------------------------------------------------------
// Utilitas
// ---------------------------------------------------------------

class ApiError extends Exception
{
    public int $status;
    public function __construct(string $message, int $status = 400)
    {
        parent::__construct($message);
        $this->status = $status;
    }
}

function fail(string $message, int $status = 400): void
{
    throw new ApiError($message, $status);
}

function out(array $data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

// ---------------------------------------------------------------
// Konfigurasi & koneksi
// ---------------------------------------------------------------

function load_config(): array
{
    $file = __DIR__ . '/config.php';
    if (!is_file($file)) {
        fail(
            'config.php belum ada. Salin config.example.php menjadi config.php '
            . 'lalu isi DSN/user/password database.',
            500
        );
    }
    $cfg = require $file;
    if (!is_array($cfg) || empty($cfg['dsn'])) {
        fail('config.php tidak valid: kunci "dsn" wajib diisi.', 500);
    }
    return $cfg;
}

function db(array $cfg): PDO
{
    static $pdo = null;
    if ($pdo !== null) {
        return $pdo;
    }
    $dsn = (string)$cfg['dsn'];
    $isMysql = stripos($dsn, 'mysql:') === 0;
    $opts = [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ];
    if ($isMysql) {
        // Hasil integer kembali sebagai int (bukan string) -> JSON & Dart rapi.
        $opts[PDO::ATTR_EMULATE_PREPARES] = false;
    }
    try {
        $pdo = new PDO($dsn, $cfg['user'] ?? null, $cfg['pass'] ?? null, $opts);
    } catch (Throwable $e) {
        fail('Koneksi database gagal: ' . $e->getMessage(), 500);
    }
    if ($isMysql) {
        $pdo->exec("SET NAMES utf8mb4");
    }
    return $pdo;
}

// ---------------------------------------------------------------
// Whitelist tabel & kolom (anti SQL injection pada nama identifier)
// ---------------------------------------------------------------

function schema(): array
{
    return [
        'devices' => [
            'id', 'kode_inventaris', 'tanggal_evaluasi', 'plan', 'bagian',
            'device_name', 'category', 'prosesor', 'motherboard', 'ram',
            'storage', 'os_windows', 'goal', 'perlu_upgrade_ganti',
            'perlu_upgrade_repair', 'status_upgrade', 'keterangan',
            'status_stiker', 'drive_link', 'created_at', 'updated_at',
        ],
        'bagian' => ['id', 'name', 'created_at', 'updated_at'],
        'plan' => ['id', 'name', 'created_at', 'updated_at'],
        'app_settings' => ['id', 'pin_hash', 'created_at', 'updated_at'],
    ];
}

function table_columns(string $table): array
{
    $s = schema();
    if (!isset($s[$table])) {
        fail('Tabel tidak dikenal: ' . $table);
    }
    return $s[$table];
}

function qid(string $name): string
{
    return '`' . $name . '`';
}

// ---------------------------------------------------------------
// WHERE
// ---------------------------------------------------------------

/**
 * @param array $conds daftar {"col","op","value"|"values"} — disatukan dengan AND
 * @return array [string sql tanpa 'WHERE', array parameter]
 */
function conditions_sql(array $conds, array $allowed): array
{
    if (count($conds) > 20) {
        fail('Terlalu banyak kondisi WHERE.');
    }
    $sql = '';
    $params = [];
    foreach ($conds as $c) {
        if (!is_array($c)) {
            fail('Kondisi WHERE harus berupa objek.');
        }
        $col = (string)($c['col'] ?? '');
        if (!in_array($col, $allowed, true)) {
            fail('Kolom tidak diizinkan: ' . $col);
        }
        $op = strtoupper((string)($c['op'] ?? '='));
        if ($op === 'IN') {
            $vals = $c['values'] ?? [];
            if (!is_array($vals) || $vals === []) {
                $sql .= ' AND 1 = 0';
                continue;
            }
            if (count($vals) > 5000) {
                fail('Terlalu banyak nilai dalam IN.');
            }
            $ph = [];
            foreach ($vals as $v) {
                $k = ':w' . count($params);
                $ph[] = $k;
                $params[$k] = $v;
            }
            $sql .= ' AND ' . qid($col) . ' IN (' . implode(',', $ph) . ')';
        } elseif ($op === '=' || $op === '!=') {
            $k = ':w' . count($params);
            $params[$k] = $c['value'] ?? null;
            $sql .= ' AND ' . qid($col) . ' ' . $op . ' ' . $k;
        } else {
            fail('Operator WHERE tidak didukung: ' . $op);
        }
    }
    return [$sql, $params];
}

/** Ambil nilai kolom pertama dari kondisi (untuk upsert per-baris). */
function first_eq_value(array $conds, string $col)
{
    foreach ($conds as $c) {
        if (is_array($c) && ($c['col'] ?? '') === $col && ($c['op'] ?? '=') === '=') {
            return $c['value'] ?? null;
        }
    }
    return null;
}

// ---------------------------------------------------------------
// Tulis (insert / update / delete / upsert) — semuanya menaikkan rev
// ---------------------------------------------------------------

function bump_rev(PDO $pdo): void
{
    $n = $pdo->exec('UPDATE app_state SET rev = rev + 1 WHERE id = 1');
    if ($n === 0) {
        try {
            $pdo->exec('INSERT INTO app_state (id, rev) VALUES (1, 1)');
        } catch (PDOException $e) {
            // baris sudah ada (balapan dua request) -> abaikan
        }
    }
}

function clean_row(array $row, array $allowed): array
{
    $out = [];
    foreach ($row as $k => $v) {
        if (!in_array((string)$k, $allowed, true)) {
            fail('Kolom tidak diizinkan: ' . $k);
        }
        $out[(string)$k] = $v;
    }
    return $out;
}

function insert_row(PDO $pdo, string $table, array $allowed, array $row): void
{
    $row = clean_row($row, $allowed);
    if ($row === []) {
        fail('Baris kosong — tidak ada kolom untuk disisipkan.');
    }
    $cols = [];
    $ph = [];
    $vals = [];
    foreach ($row as $k => $v) {
        $cols[] = qid($k);
        $ph[] = '?';
        $vals[] = $v;
    }
    $sql = 'INSERT INTO ' . qid($table) . ' (' . implode(',', $cols) . ') VALUES (' . implode(',', $ph) . ')';
    $st = $pdo->prepare($sql);
    $st->execute($vals);
}

function update_row(PDO $pdo, string $table, array $allowed, array $row, $id): void
{
    $row = clean_row($row, $allowed);
    unset($row['id'], $row['created_at']);
    if ($row === []) {
        return;
    }
    $set = [];
    $vals = [];
    foreach ($row as $k => $v) {
        $set[] = qid($k) . ' = ?';
        $vals[] = $v;
    }
    $vals[] = $id;
    $sql = 'UPDATE ' . qid($table) . ' SET ' . implode(', ', $set) . ' WHERE ' . qid('id') . ' = ?';
    $pdo->prepare($sql)->execute($vals);
}

// ---------------------------------------------------------------
// Pencatatan hasil fetch (int di JSON, bukan string)
// ---------------------------------------------------------------

function cast_ids(array $rows): array
{
    foreach ($rows as &$r) {
        if (isset($r['id']) && is_numeric($r['id'])) {
            $r['id'] = (int)$r['id'];
        }
    }
    unset($r);
    return $rows;
}

// ---------------------------------------------------------------
// Operasi
// ---------------------------------------------------------------

function op_ping(): void
{
    out(['ok' => true, 'app' => 'spek-komputer-api', 'time' => gmdate('c')]);
}

function op_rev(array $cfg): void
{
    $pdo = db($cfg);
    $counts = [];
    foreach (array_keys(schema()) as $t) {
        $counts[$t] = (int)$pdo->query('SELECT COUNT(*) FROM ' . qid($t))->fetchColumn();
    }
    try {
        $r = $pdo->query('SELECT rev FROM app_state WHERE id = 1')->fetchColumn();
    } catch (PDOException $e) {
        $r = false;
    }
    $rev = ($r === false || $r === null) ? 0 : (int)$r;
    out(['ok' => true, 'rev' => $rev, 'counts' => $counts]);
}

function op_migrate(array $cfg): void
{
    $pdo = db($cfg);
    $sqlite = stripos((string)$cfg['dsn'], 'sqlite:') === 0;
    $file = $sqlite ? __DIR__ . '/schema.sqlite.sql' : __DIR__ . '/schema.sql';
    if (!is_file($file)) {
        fail('File skema tidak ditemukan: ' . $file, 500);
    }
    $sql = (string)file_get_contents($file);
    if ($sqlite) {
        // sqlite3_exec menerima banyak perintah sekaligus (termasuk trigger)
        $pdo->exec($sql);
    } else {
        // MySQL: eksekusi per perintah (PDO tidak mengizinkan multi-statement)
        foreach (preg_split('/;\s*(?:\r?\n|$)/', $sql) as $stmt) {
            $stmt = trim($stmt);
            if ($stmt === '') {
                continue;
            }
            if (trim(preg_replace('/^\s*--.*$/m', '', $stmt)) === '') {
                continue; // baris komentar saja
            }
            $pdo->exec($stmt);
        }
    }
    out(['ok' => true, 'migrated' => true, 'engine' => $sqlite ? 'sqlite' : 'mysql']);
}

function op_select(array $cfg, array $body): void
{
    $table = (string)($body['table'] ?? '');
    $allowed = table_columns($table);

    $cols = $body['columns'] ?? null;
    if (is_array($cols) && $cols !== []) {
        foreach ($cols as $c) {
            if (!in_array((string)$c, $allowed, true)) {
                fail('Kolom tidak diizinkan: ' . $c);
            }
        }
        $colSql = implode(',', array_map('qid', array_map('strval', $cols)));
    } else {
        $colSql = '*';
    }

    $sql = 'SELECT ' . $colSql . ' FROM ' . qid($table) . ' WHERE 1 = 1';
    [$w, $wp] = conditions_sql($body['where'] ?? [], $allowed);
    $sql .= $w;

    $order = $body['order'] ?? null;
    if (is_array($order) && !empty($order['by'])) {
        $by = (string)$order['by'];
        if (!in_array($by, $allowed, true)) {
            fail('Kolom tidak diizinkan: ' . $by);
        }
        $sql .= ' ORDER BY ' . qid($by) . (!empty($order['desc']) ? ' DESC' : ' ASC');
    }

    if (isset($body['limit'])) {
        $limit = (int)$body['limit'];
        if ($limit < 1 || $limit > 100000) {
            fail('limit harus 1..100000');
        }
        $sql .= ' LIMIT ' . $limit;
    }

    $st = db($cfg)->prepare($sql);
    $st->execute($wp);
    out(['ok' => true, 'rows' => cast_ids($st->fetchAll())]);
}

function op_insert(array $cfg, array $body): void
{
    $table = (string)($body['table'] ?? '');
    $allowed = table_columns($table);
    $rows = $body['rows'] ?? [];
    if (!is_array($rows) || $rows === []) {
        fail('Kunci "rows" wajib berupa array berisi objek.');
    }
    if (count($rows) > 5000) {
        fail('Terlalu banyak baris dalam satu request (maks 5000).');
    }

    $pdo = db($cfg);
    // Satu daftar kolom untuk semua baris (seragam) -> SQL bulk satu langkah.
    $cols = [];
    foreach ($rows as $r) {
        if (!is_array($r)) {
            fail('Setiap baris harus berupa objek.');
        }
        foreach (array_keys($r) as $k) {
            $cols[(string)$k] = true;
        }
    }
    $colNames = array_keys($cols);
    foreach ($colNames as $c) {
        if (!in_array($c, $allowed, true)) {
            fail('Kolom tidak diizinkan: ' . $c);
        }
    }
    if ($colNames === []) {
        fail('Tidak ada kolom pada baris yang dikirim.');
    }

    $lines = [];
    $vals = [];
    foreach ($rows as $r) {
        $ph = [];
        foreach ($colNames as $c) {
            $ph[] = '?';
            $vals[] = array_key_exists($c, $r) ? $r[$c] : null;
        }
        $lines[] = '(' . implode(',', $ph) . ')';
    }
    $sql = 'INSERT INTO ' . qid($table)
        . ' (' . implode(',', array_map('qid', $colNames)) . ') VALUES '
        . implode(',', $lines);
    $pdo->prepare($sql)->execute($vals);
    bump_rev($pdo);

    if (empty($body['returning'])) {
        out(['ok' => true, 'count' => count($rows)]);
    }

    // Kembalikan baris pertama (klien membutuhkan id hasil insert).
    $lastId = (int)$pdo->lastInsertId();
    $first = is_array($rows[0]) ? $rows[0] : [];
    $returned = [];
    if ($lastId > 0) {
        $st = $pdo->prepare('SELECT * FROM ' . qid($table) . ' WHERE id = ?');
        $st->execute([$lastId]);
        $returned = $st->fetchAll();
    } elseif (isset($first['id'])) {
        $st = $pdo->prepare('SELECT * FROM ' . qid($table) . ' WHERE id = ?');
        $st->execute([$first['id']]);
        $returned = $st->fetchAll();
    }
    out(['ok' => true, 'count' => count($rows), 'rows' => cast_ids($returned)]);
}

function op_update(array $cfg, array $body): void
{
    $table = (string)($body['table'] ?? '');
    $allowed = table_columns($table);
    $set = $body['set'] ?? null;
    if (!is_array($set) || $set === []) {
        fail('Kunci "set" wajib berupa objek berisi kolom yang diubah.');
    }
    [$w, $wp] = conditions_sql($body['where'] ?? [], $allowed);
    if ($w === '') {
        fail('UPDATE tanpa WHERE ditolak.');
    }

    $row = clean_row($set, $allowed);
    unset($row['id'], $row['created_at']);
    if ($row === []) {
        fail('Tidak ada kolom yang boleh diubah.');
    }
    $setSql = [];
    $params = [];
    foreach ($row as $k => $v) {
        $setSql[] = qid($k) . ' = ?';
        $params[] = $v;
    }
    $sql = 'UPDATE ' . qid($table) . ' SET ' . implode(', ', $setSql) . ' WHERE 1 = 1' . $w;

    $pdo = db($cfg);
    $st = $pdo->prepare($sql);
    $st->execute(array_merge($params, array_values($wp)));
    bump_rev($pdo);
    out(['ok' => true, 'affected' => $st->rowCount()]);
}

function op_delete(array $cfg, array $body): void
{
    $table = (string)($body['table'] ?? '');
    $allowed = table_columns($table);
    [$w, $wp] = conditions_sql($body['where'] ?? [], $allowed);
    if ($w === '') {
        fail('DELETE tanpa WHERE ditolak.');
    }

    $pdo = db($cfg);
    $st = $pdo->prepare('DELETE FROM ' . qid($table) . ' WHERE 1 = 1' . $w);
    $st->execute($wp);
    bump_rev($pdo);
    out(['ok' => true, 'affected' => $st->rowCount()]);
}

function op_upsert(array $cfg, array $body): void
{
    $table = (string)($body['table'] ?? '');
    $allowed = table_columns($table);
    $conflict = (string)($body['on_conflict'] ?? '');
    if (!in_array($conflict, $allowed, true)) {
        fail('on_conflict harus salah satu kolom tabel: ' . $conflict);
    }
    $rows = $body['rows'] ?? [];
    if (!is_array($rows) || $rows === []) {
        fail('Kunci "rows" wajib berupa array berisi objek.');
    }
    if (count($rows) > 5000) {
        fail('Terlalu banyak baris dalam satu request (maks 5000).');
    }

    $pdo = db($cfg);
    $inserted = 0;
    $updated = 0;
    $pdo->beginTransaction();
    try {
        $find = $pdo->prepare('SELECT id FROM ' . qid($table) . ' WHERE ' . qid($conflict) . ' = ? LIMIT 1');
        foreach ($rows as $r) {
            if (!is_array($r)) {
                fail('Setiap baris harus berupa objek.');
            }
            $key = array_key_exists($conflict, $r) ? $r[$conflict] : null;
            if ($key === null || $key === '') {
                insert_row($pdo, $table, $allowed, $r);
                $inserted++;
                continue;
            }
            $find->execute([$key]);
            $id = $find->fetchColumn();
            if ($id === false) {
                insert_row($pdo, $table, $allowed, $r);
                $inserted++;
            } else {
                update_row($pdo, $table, $allowed, $r, $id);
                $updated++;
            }
        }
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $e;
    }
    bump_rev($pdo);
    out(['ok' => true, 'inserted' => $inserted, 'updated' => $updated]);
}

// ---------------------------------------------------------------
// Penanganan request
// ---------------------------------------------------------------

$cfg = null;
$cfgError = null;
try {
    $cfg = load_config();
} catch (ApiError $e) {
    $cfgError = $e;
}

$allow = (string)($cfg['allow_origin'] ?? '*');
$origin = (string)($_SERVER['HTTP_ORIGIN'] ?? '');
if ($allow === '*' || ($origin !== '' && $allow === $origin)) {
    header('Access-Control-Allow-Origin: ' . ($allow === '*' ? '*' : $origin));
    header('Vary: Origin');
}
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Api-Key');
header('Access-Control-Max-Age: 600');
header('Cache-Control: no-store');

$method = (string)($_SERVER['REQUEST_METHOD'] ?? 'GET');
if ($method === 'OPTIONS') {
    http_response_code(204);
    exit;
}
if ($method !== 'GET' && $method !== 'POST') {
    out(['ok' => false, 'error' => 'Metode tidak diizinkan. Gunakan GET atau POST.'], 405);
}

try {
    if ($cfgError !== null) {
        throw $cfgError;
    }

    $body = [];
    $raw = file_get_contents('php://input');
    if (is_string($raw) && trim($raw) !== '') {
        $decoded = json_decode($raw, true);
        if (!is_array($decoded)) {
            fail('Body harus JSON yang valid.');
        }
        $body = $decoded;
    }
    $body = array_merge($_GET, $body);

    // Autentikasi kunci bersama
    $key = (string)($cfg['api_key'] ?? '');
    if ($key !== '') {
        $given = (string)($_SERVER['HTTP_X_API_KEY'] ?? '');
        if ($given === '' || !hash_equals($key, $given)) {
            out(['ok' => false, 'error' => 'API key salah atau tidak dikirim (header X-Api-Key).'], 401);
        }
    }

    $op = (string)($body['op'] ?? '');
    switch ($op) {
        case 'ping':
            op_ping();
            break;
        case 'rev':
            op_rev($cfg);
            break;
        case 'migrate':
            op_migrate($cfg);
            break;
        case 'select':
            op_select($cfg, $body);
            break;
        case 'insert':
            op_insert($cfg, $body);
            break;
        case 'update':
            op_update($cfg, $body);
            break;
        case 'delete':
            op_delete($cfg, $body);
            break;
        case 'upsert':
            op_upsert($cfg, $body);
            break;
        default:
            fail('op tidak dikenal: ' . ($op === '' ? '(kosong)' : $op));
    }
} catch (ApiError $e) {
    out(['ok' => false, 'error' => $e->getMessage()], $e->status);
} catch (PDOException $e) {
    $msg = $e->getMessage();
    if (stripos($msg, 'no such table') !== false || stripos($msg, "doesn't exist") !== false) {
        $msg .= ' — tabel belum dibuat; jalankan op=migrate atau impor schema.sql di phpMyAdmin.';
    }
    $isIntegrity = ($e->getCode() === '23000' || stripos($msg, 'UNIQUE constraint failed') !== false
        || stripos($msg, 'Duplicate entry') !== false || stripos($msg, 'FOREIGN KEY constraint failed') !== false);
    if ($isIntegrity) {
        out(['ok' => false, 'error' => 'Bentrok data (duplikat/unique): ' . $msg], 409);
    }
    out(['ok' => false, 'error' => 'Database: ' . $msg], 500);
} catch (Throwable $e) {
    out(['ok' => false, 'error' => 'Server: ' . $e->getMessage()], 500);
}
