// Supabase bağlantı bilgileri.
// Güvenlik: Proje URL'i ve publishable anahtar derleme sırasında --dart-define ile verilir.
// Örnek: flutter run -d chrome --dart-define=SUPABASE_URL=https://PROJE_ADRESI.supabase.co --dart-define=SUPABASE_ANON_KEY=ANAHTAR
// Gerçek yetkilendirme veritabanındaki RLS politikalarında yapılır; service_role anahtarı ASLA istemciye girmez.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://YOUR_PROJECT_ID.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'YOUR_SUPABASE_PUBLISHABLE_KEY',
);
