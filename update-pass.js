const { Client } = require('pg');
const bcrypt = require('bcrypt');

async function main() {
  const hash = await bcrypt.hash('Test1234!', 10);
  const client = new Client({
    host: 'postgres',
    port: 5432,
    user: 'postgres',
    password: 'postgres',
    database: 'finanzas_latam',
  });
  await client.connect();
  await client.query(
    "UPDATE users SET password_hash = $1, email_verified = true WHERE email = 'ana@test.com'",
    [hash]
  );
  const { rows } = await client.query("SELECT password_hash FROM users WHERE email = 'ana@test.com'");
  console.log('Updated hash prefix:', rows[0].password_hash.substring(0, 10));
  await client.end();
}

main().catch(console.error);
