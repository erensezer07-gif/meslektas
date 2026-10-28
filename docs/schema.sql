-- ============================================================
-- eslesme_app — Veritabanı Şeması (MVP)
-- Tek doğru kaynak: docs/schema.sql
-- Boş bir Supabase projesine BİR KEZ, tek migration olarak uygulanır.
-- Kapsam ve kararlar için bkz. docs/mvp.md
-- ============================================================

-- ------------------------------------------------------------
-- 0) UZANTILAR
-- ------------------------------------------------------------
-- updated_at kolonunu otomatik güncelleyen hazır fonksiyon
create extension if not exists moddatetime with schema extensions;

-- ------------------------------------------------------------
-- 1) PROFİLLER
-- ------------------------------------------------------------
-- Not: Zorunlu alan denetimi (foto, şehir, en az 1 etiket vb.)
-- esneklik için uygulama tarafında yapılır; veritabanı yalnızca
-- ad soyadı zorunlu tutar.
create table public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  full_name        text not null,
  title            text,                          -- ünvan: "CEO", "Tesisat Ustası" (sadece görüntülenir)
  bio              text,
  city             text,                          -- uygulamada 81 il listesinden seçtirilir
  skills           text[] not null default '{}',  -- yetkinlik etiketleri (küçük harf)
  looking_for      text[] not null default '{}',  -- arayış etiketleri (küçük harf)
  avatar_url       text,                          -- avatars deposundaki fotoğrafın public URL'i
  height_cm        smallint check (height_cm between 100 and 250),   -- opsiyonel
  weight_kg        smallint check (weight_kg between 30 and 300),    -- opsiyonel
  cv_path          text,                          -- cvs deposundaki dosya yolu (örn. "{uid}/cv.pdf")
  experience_years smallint check (experience_years between 0 and 60),
  education        text,                          -- "Sivas Cumhuriyet Ünv. · Bilgisayar Müh."
  languages        text[] default '{}',
  link_linkedin    text,
  link_github      text,
  link_website     text,
  work_preference  text check (work_preference in ('yerinde','uzaktan','hibrit')),
  certificates     text[] default '{}',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- updated_at otomatik güncellensin
create trigger set_profiles_updated_at
  before update on public.profiles
  for each row execute function extensions.moddatetime(updated_at);

alter table public.profiles enable row level security;

create policy "Profiller: giriş yapan herkes görebilir"
  on public.profiles for select to authenticated
  using (true);

create policy "Profiller: kendi profilini oluştur"
  on public.profiles for insert to authenticated
  with check (auth.uid() = id);

create policy "Profiller: kendi profilini güncelle"
  on public.profiles for update to authenticated
  using (auth.uid() = id);

-- ------------------------------------------------------------
-- 2) SWIPE'LAR (kaydırmalar)
-- ------------------------------------------------------------
create table public.swipes (
  id         bigint generated always as identity primary key,
  swiper_id  uuid not null references public.profiles(id) on delete cascade,
  swiped_id  uuid not null references public.profiles(id) on delete cascade,
  is_like    boolean not null,                    -- true: beğen, false: geç
  created_at timestamptz not null default now(),
  unique (swiper_id, swiped_id),                  -- aynı kişiye ikinci kez swipe yok
  check (swiper_id <> swiped_id)                  -- kendine swipe yok
);

-- Trigger'ın "karşı beğeni var mı" aramasını hızlandırır
create index idx_swipes_swiped on public.swipes (swiped_id);

alter table public.swipes enable row level security;

create policy "Swipe: kendi kaydırmanı ekle"
  on public.swipes for insert to authenticated
  with check (auth.uid() = swiper_id);

create policy "Swipe: kendi kaydırmalarını gör"
  on public.swipes for select to authenticated
  using (auth.uid() = swiper_id);

-- Geri alma: kullanıcı yalnızca KENDİ kaydırmasını ve yalnızca eşleşme
-- OLUŞMAMIŞSA silebilir. Eşleşmeyi bozmak istemciden mümkün değildir.
create policy "Swipe: eşleşme yoksa geri al"
  on public.swipes for delete to authenticated
  using (
    swiper_id = auth.uid()
    and not exists (
      select 1 from public.matches m
      where m.user1_id = least(swipes.swiper_id, swipes.swiped_id)
        and m.user2_id = greatest(swipes.swiper_id, swipes.swiped_id)
    )
  );

-- ------------------------------------------------------------
-- 3) EŞLEŞMELER
-- ------------------------------------------------------------
-- ÖNEMLİ: insert politikası bilerek YOK. Eşleşmeyi yalnızca
-- aşağıdaki trigger (sunucu tarafı) oluşturabilir; istemciden
-- sahte eşleşme yaratılamaz.
create table public.matches (
  id         bigint generated always as identity primary key,
  user1_id   uuid not null references public.profiles(id) on delete cascade,
  user2_id   uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user1_id, user2_id),
  check (user1_id < user2_id)                     -- aynı çift tek satır olsun diye sıralı tutulur
);

create index idx_matches_user1 on public.matches (user1_id);
create index idx_matches_user2 on public.matches (user2_id);

alter table public.matches enable row level security;

create policy "Eşleşme: yalnızca tarafları görebilir"
  on public.matches for select to authenticated
  using (auth.uid() = user1_id or auth.uid() = user2_id);

-- ------------------------------------------------------------
-- 4) EŞLEŞME TETİKLEYİCİSİ
-- ------------------------------------------------------------
-- Yeni bir beğeni geldiğinde karşı yönde beğeni var mı bakar;
-- varsa matches tablosuna eşleşmeyi otomatik ekler.
create or replace function public.handle_swipe()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_like and exists (
    select 1
    from public.swipes s
    where s.swiper_id = new.swiped_id
      and s.swiped_id = new.swiper_id
      and s.is_like
  ) then
    insert into public.matches (user1_id, user2_id)
    values (
      least(new.swiper_id, new.swiped_id),
      greatest(new.swiper_id, new.swiped_id)
    )
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger on_swipe_created
  after insert on public.swipes
  for each row execute function public.handle_swipe();

-- ------------------------------------------------------------
-- 5) MESAJLAR
-- ------------------------------------------------------------
create table public.messages (
  id         bigint generated always as identity primary key,
  match_id   bigint not null references public.matches(id) on delete cascade,
  sender_id  uuid not null references public.profiles(id) on delete cascade,
  content    text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now()
);

-- Sohbet geçmişini hızlı yükler
create index idx_messages_match_created on public.messages (match_id, created_at);

alter table public.messages enable row level security;

create policy "Mesaj: eşleşmenin tarafları okuyabilir"
  on public.messages for select to authenticated
  using (exists (
    select 1 from public.matches m
    where m.id = match_id
      and (m.user1_id = auth.uid() or m.user2_id = auth.uid())
  ));

create policy "Mesaj: eşleşmenin tarafı olarak gönder"
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.matches m
      where m.id = match_id
        and (m.user1_id = auth.uid() or m.user2_id = auth.uid())
    )
  );

-- Mesajlar gerçek zamanlı dinlenebilsin (Realtime)
alter publication supabase_realtime add table public.messages;

-- ------------------------------------------------------------
-- 6) ETİKET KATALOĞU + DESTE FONKSİYONU (puanlı sıralama)
-- ------------------------------------------------------------
-- Etiket kataloğu: küçük harfli etiket → kategori eşlemesi.
-- get_deck() kategori puanı için kullanır. İçerik lib/constants/tags.dart'tan
-- üretilir (turkishLower ile); etiket listesi değişince bu tablo da
-- güncellenmelidir. Elle SQL ile veri girerken lower() KULLANMA — uygulamanın
-- turkishLower kuralı geçerlidir (I→ı: 'IT Destek' → 'ıt destek').
create table public.tag_catalog (
  tag      text primary key,  -- turkishLower ile küçük harfli hali
  category text not null      -- görünen kategori adı
);

alter table public.tag_catalog enable row level security;

-- Salt-okunur referans verisi: giriş yapmış herkes okuyabilir, kimse yazamaz.
create policy "tag_catalog_select" on public.tag_catalog
  for select to authenticated using (true);

insert into public.tag_catalog (tag, category)
select unnest(array[
  'python', 'javascript', 'java', 'c#', 'c++', 'typescript', 'php', 'go', 'dart', 'kotlin',
  'swift', 'objective-c', 'c', 'rust', 'ruby', 'scala', 'r', 'matlab', 'perl', 'lua',
  'haskell', 'elixir', 'erlang', 'clojure', 'f#', 'visual basic', 'vba', 'delphi', 'cobol',
  'fortran', 'assembly', 'solidity', 'bash & shell', 'powershell', 'groovy', 'julia'
]), 'Yazılım — Programlama Dilleri'
union all
select unnest(array[
  'web geliştirme', 'mobil uygulama', 'frontend', 'backend', 'flutter', 'react', '.net',
  'oyun geliştirme', 'full-stack', 'html & css', 'tailwind css', 'bootstrap', 'sass', 'jquery',
  'angular', 'vue.js', 'svelte', 'next.js', 'nuxt', 'node.js', 'express', 'nestjs', 'django',
  'flask', 'fastapı', 'spring boot', 'asp.net core', '.net mauı', 'wpf', 'winforms', 'laravel',
  'symfony', 'ruby on rails', 'wordpress', 'woocommerce', 'shopify', 'webflow', 'wix',
  'opencart', 'react native', 'android geliştirme', 'ios geliştirme', 'swiftuı',
  'jetpack compose', 'xamarin', 'ıonic', 'rest apı', 'graphql', 'websocket',
  'mikroservis mimarisi', 'unity', 'unreal engine', 'godot', 'ar/vr geliştirme', 'electron',
  'yazılım testi (qa)', 'test otomasyonu (selenium)'
]), 'Yazılım — Web, Mobil & Oyun'
union all
select unnest(array[
  'yapay zeka & veri', 'veri analizi', 'sql', 'power bı', 'excel (ileri düzey)',
  'makine öğrenmesi', 'veritabanı', 'tableau', 'veri bilimi', 'veri mühendisliği',
  'iş zekası (bı)', 'derin öğrenme', 'doğal dil işleme (nlp)', 'bilgisayarlı görü',
  'üretken yapay zeka', 'llm uygulamaları', 'prompt mühendisliği', 'tensorflow', 'pytorch',
  'keras', 'scikit-learn', 'pandas', 'numpy', 'opencv', 'hugging face', 'langchain',
  'rag sistemleri', 'qlik sense', 'looker studio', 'google sheets', 't-sql', 'pl/sql',
  'postgresql', 'mysql', 'sql server', 'oracle', 'mongodb', 'redis', 'elasticsearch',
  'firebase', 'supabase', 'snowflake', 'bigquery', 'databricks', 'apache spark', 'hadoop',
  'apache kafka', 'apache airflow', 'dbt', 'etl & veri ambarı', 'veri görselleştirme',
  'a/b testi', 'istatistiksel analiz', 'web kazıma (scraping)'
]), 'Veri & Yapay Zeka'
union all
select unnest(array[
  'ıt destek', 'siber güvenlik', 'devops', 'aws', 'docker', 'linux', 'ağ yönetimi',
  'sistem yönetimi', 'microsoft azure', 'google cloud', 'kubernetes', 'terraform', 'ansible',
  'jenkins', 'github actions', 'gitlab cı', 'cı/cd', 'git', 'nginx', 'apache', 'ııs',
  'windows server', 'active directory', 'microsoft 365 yönetimi', 'google workspace',
  'sanallaştırma (vmware)', 'proxmox', 'prometheus & grafana', 'elk stack', 'sıem',
  'soc analistliği', 'sızma testi (pentest)', 'zafiyet analizi', 'ağ güvenliği',
  'firewall yönetimi', 'adli bilişim', 'ıso 27001', 'yedekleme & felaket kurtarma',
  'veritabanı yönetimi (dba)', 'voıp & ıp santral', 'cctv & kamera sistemleri',
  'teknik servis', 'helpdesk', 'mikrotik', 'cisco ağ cihazları', 'fiber optik',
  'ağ kablolama & altyapı'
]), 'DevOps, Bulut & IT'
union all
select unnest(array[
  'makine mühendisliği', 'autocad', 'solidworks', 'cnc programlama', 'makine tasarımı',
  'üretim planlama', 'kalite kontrol', 'bakım mühendisliği', 'catıa', 'siemens nx',
  'autodesk ınventor', 'fusion 360', 'ptc creo', 'ansys', 'sonlu elemanlar analizi (fea)',
  'cfd analizi', 'cam (mastercam)', 'cnc operatörlüğü', 'torna & freze', 'talaşlı imalat',
  'sac metal tasarımı', 'kalıp tasarımı', 'plastik enjeksiyon', '3d baskı (eklemeli imalat)',
  'tersine mühendislik', 'teknik ressamlık', 'gd&t (toleranslandırma)', 'kaynak mühendisliği',
  'hidrolik & pnömatik', 'hvac tasarımı', 'soğutma sistemleri', 'mekanik tesisat projesi',
  'üretim mühendisliği', 'proses iyileştirme', 'kestirimci bakım', 'tpm', 'ölçüm & metroloji',
  'cmm ölçüm', 'otomotiv mühendisliği', 'havacılık mühendisliği', 'gemi inşa mühendisliği',
  'raylı sistemler', 'ar-ge mühendisliği', 'proje mühendisliği'
]), 'Mühendislik — Makine & Üretim'
union all
select unnest(array[
  'elektrik mühendisliği', 'elektronik mühendisliği', 'plc programlama', 'otomasyon',
  'mekatronik', 'gömülü sistemler', 'robotik', 'elektrik proje (ag/yg)', 'siemens tıa portal',
  'scada', 'hmı tasarımı', 'dcs sistemleri', 'endüstriyel robot (kuka/abb/fanuc)',
  'servo & motor sürücüleri', 'sensörler & enstrümantasyon', 'mikrodenetleyici (stm32)',
  'arduino', 'raspberry pi', 'esp32 & ıot', 'rtos', 'gömülü linux', 'pcb tasarımı',
  'altium designer', 'kicad', 'devre tasarımı', 'güç elektroniği', 'fpga (vhdl/verilog)',
  'sinyal işleme (dsp)', 'haberleşme sistemleri', 'rf & anten tasarımı', 'yüksek gerilim',
  'trafo merkezleri', 'enerji dağıtımı', 'kompanzasyon', 'elektrik pano tasarımı', 'eplan',
  'aydınlatma tasarımı (dıalux)', 'zayıf akım sistemleri', 'yangın algılama sistemleri',
  'kalibrasyon', 'biyomedikal cihaz teknolojisi'
]), 'Mühendislik — Elektrik & Elektronik'
union all
select unnest(array[
  'inşaat mühendisliği', 'mimarlık', 'statik proje', 'şantiye şefliği', 'revit', 'bım',
  'metraj', 'hakediş', 'mimari proje', 'betonarme tasarım', 'çelik yapı tasarımı', 'sap2000',
  'etabs', 'sta4cad', 'idecad', 'tekla structures', 'saha mühendisliği',
  'keşif & maliyet analizi', 'ihale dosyası hazırlama', 'yapı denetim',
  'iş güvenliği uzmanlığı', 'zemin etüdü (geoteknik)', 'jeoloji mühendisliği',
  'harita mühendisliği', 'gıs (coğrafi bilgi sistemleri)', 'netcad',
  'fotogrametri & drone haritalama', 'ulaşım & yol projesi',
  'altyapı projesi (içmesuyu/kanalizasyon)', 'hidrolik & su yapıları', 'çevre mühendisliği',
  'atıksu arıtma', 'çed raporu', 'restorasyon', 'peyzaj mimarlığı'
]), 'Mühendislik — İnşaat & Yapı'
union all
select unnest(array[
  'endüstri mühendisliği', 'kalite mühendisliği', 'yalın üretim', 'six sigma',
  'enerji yönetimi', 'güneş enerjisi (ges)', 'kimya mühendisliği', 'gıda mühendisliği',
  'kalite güvence (qa)', 'ıso 9001', 'ıatf 16949', 'ıso 14001', 'fmea',
  'spc (istatistiksel proses kontrol)', 'kaizen', '5s', 'zaman etüdü',
  'tedarik zinciri yönetimi', 'enerji mühendisliği', 'enerji verimliliği',
  'rüzgar enerjisi (res)', 'elektrikli araç şarj sistemleri', 'proses mühendisliği',
  'gıda güvenliği (haccp)', 'tekstil mühendisliği', 'metalurji & malzeme mühendisliği',
  'ısıl işlem', 'korozyon & kaplama', 'maden mühendisliği', 'petrol & doğalgaz mühendisliği',
  'ziraat mühendisliği', 'biyomedikal mühendisliği'
]), 'Mühendislik — Endüstri, Enerji & Diğer'
union all
select unnest(array[
  'tesisat', 'elektrik', 'boya-badana', 'marangozluk', 'kaynak', 'klima-kombi',
  'inşaat-tadilat', 'mobilya montaj', 'çilingir', 'cam-balkon', 'seramik & fayans',
  'alçıpan & asma tavan', 'parke & zemin döşeme', 'çatı ustalığı', 'su yalıtımı',
  'ısı yalıtımı (mantolama)', 'demir doğrama', 'alüminyum doğrama', 'pvc pencere & kapı',
  'duvar örme & sıva', 'mermer & granit', 'beyaz eşya tamiri', 'elektronik tamir',
  'telefon & tablet tamiri', 'bilgisayar tamiri', 'oto mekanik', 'oto elektrik',
  'kaporta & boya', 'oto ekspertiz', 'motosiklet tamiri', 'asansör bakımı', 'jeneratör bakımı',
  'güneş paneli montajı', 'uydu & anten servisi', 'ayakkabı tamiri', 'saat tamiri',
  'kuyumculuk', 'mobilya döşemeciliği', 'oto lastik & rot balans'
]), 'Usta / Zanaat'
union all
select unnest(array[
  'grafik tasarım', 'uı/ux', 'logo tasarım', 'video kurgu', '3d modelleme', 'adobe photoshop',
  'figma', 'iç mimarlık', 'fotoğrafçılık', 'adobe ıllustrator', 'adobe ındesign',
  'adobe premiere pro', 'after effects', 'davinci resolve', 'final cut pro', 'capcut',
  'adobe xd', 'sketch', 'canva', 'blender', 'cinema 4d', '3ds max', 'maya', 'zbrush',
  'sketchup', 'lumion', 'v-ray', 'mimari görselleştirme', 'motion graphics', '2d animasyon',
  '3d animasyon', 'karakter tasarımı', 'illüstrasyon', 'dijital çizim', 'ambalaj tasarımı',
  'kurumsal kimlik tasarımı', 'baskıya hazırlık (matbaa)', 'web tasarımı',
  'sosyal medya görselleri', 'sunum tasarımı', 'moda tasarımı', 'takı tasarımı',
  'endüstriyel tasarım', 'ürün fotoğrafçılığı', 'etkinlik fotoğrafçılığı', 'drone çekimi',
  'fotoğraf rötuşu', 'video prodüksiyon'
]), 'Tasarım'
union all
select unnest(array[
  'muhasebe', 'ön muhasebe', 'insan kaynakları', 'finans danışmanlığı', 'proje yönetimi',
  'sap', 'müşteri hizmetleri', 'hukuk danışmanlığı', 'asistanlık', 'mali müşavirlik',
  'vergi danışmanlığı', 'bordro & özlük', 'sgk işlemleri', 'e-fatura & e-defter',
  'logo yazılım', 'mikro yazılım', 'netsis', 'luca', 'erp yönetimi', 'finansal analiz',
  'bütçe & raporlama', 'finansal modelleme', 'yatırım analizi', 'sigortacılık', 'denetim',
  'iç denetim & risk', 'dış ticaret', 'ithalat & ihracat operasyonu', 'gümrük müşavirliği',
  'lojistik yönetimi', 'tedarik & satın alma', 'depo & envanter yönetimi', 'pmp',
  'agile & scrum', 'jira & confluence', 'iş analizi', 'ürün yönetimi', 'crm yönetimi',
  'ofis programları (ms office)', 'veri girişi', 'çağrı merkezi', 'santral & ön büro',
  'emlak danışmanlığı', 'kvkk uyum', 'arabuluculuk', 'avukatlık',
  'marka & patent vekilliği', 'icra & alacak takibi', 'bankacılık',
  'sigorta eksperliği', 'gayrimenkul değerleme', 'aktüerya'
]), 'Finans & Ofis'
union all
select unnest(array[
  'sosyal medya yönetimi', 'dijital pazarlama', 'seo', 'e-ticaret', 'satış', 'google ads',
  'içerik yazarlığı', 'reklam', 'ınstagram yönetimi', 'tiktok içerik üretimi',
  'youtube kanal yönetimi', 'linkedın pazarlama', 'ınfluencer pazarlama', 'topluluk yönetimi',
  'meta ads', 'reklam metni (copywriting)', 'e-posta pazarlama', 'pazarlama stratejisi',
  'marka yönetimi', 'halkla ilişkiler (pr)', 'pazar araştırması', 'growth hacking',
  'aso (mağaza optimizasyonu)', 'google analytics', 'trendyol mağaza yönetimi',
  'hepsiburada mağaza yönetimi', 'amazon satıcılığı', 'etsy', 'pazaryeri entegrasyonu',
  'dropshipping', 'b2b satış', 'saha satışı', 'tele-satış', 'bayi & distribütör yönetimi',
  'mağaza yönetimi (perakende)', 'merchandising'
]), 'Pazarlama & Satış'
union all
select unnest(array[
  'özel ders', 'matematik', 'ingilizce', 'yazılım eğitimi', 'fitness antrenörlüğü',
  'diyetisyenlik', 'yks hazırlık', 'kariyer koçluğu', 'müzik dersi', 'fizik', 'kimya',
  'biyoloji', 'türkçe & edebiyat', 'tarih', 'coğrafya', 'geometri', 'almanca', 'fransızca',
  'ispanyolca', 'arapça', 'rusça', 'japonca', 'korece', 'işaret dili',
  'toefl & ıelts hazırlık', 'yds hazırlık', 'lgs hazırlık', 'kpss hazırlık',
  'ales & dgs hazırlık', 'okul öncesi eğitim', 'özel eğitim', 'kodlama eğitimi (çocuklar)',
  'robotik kodlama', 'satranç eğitmenliği', 'gitar dersi', 'piyano dersi', 'keman dersi',
  'bağlama dersi', 'şan (vokal) dersi', 'resim dersi', 'drama eğitmenliği',
  'diksiyon & hitabet', 'yüzme dersi', 'tenis dersi', 'basketbol antrenörlüğü',
  'futbol antrenörlüğü', 'pilates eğitmenliği', 'yoga eğitmenliği', 'kişisel antrenörlük (pt)',
  'beslenme koçluğu', 'yaşam koçluğu', 'direksiyon dersi', 'öğretmenlik',
  'akademisyenlik', 'rehberlik (pdr)'
]), 'Eğitim & Koçluk'
union all
select unnest(array[
  'temizlik', 'nakliyat', 'kuaförlük', 'aşçılık', 'şoförlük', 'kurye', 'bahçe bakımı',
  'terzilik', 'pastacılık', 'ev temizliği', 'ofis temizliği', 'inşaat sonrası temizlik',
  'halı & koltuk yıkama', 'cam temizliği', 'ilaçlama (haşere kontrolü)', 'evden eve nakliyat',
  'şehirler arası nakliyat', 'eşya depolama', 'peyzaj uygulama', 'ağaç budama', 'havuz bakımı',
  'erkek kuaförü', 'kadın kuaförü', 'makyaj', 'cilt bakımı', 'manikür & pedikür',
  'masaj terapisi', 'abiye & özel dikim', 'kıyafet tadilatı', 'ütü & çamaşır hizmeti',
  'ev yemekleri', 'catering', 'barista', 'garsonluk', 'moto kurye', 'özel şoför',
  'vıp transfer', 'vale', 'güvenlik görevlisi', 'site & apartman yönetimi',
  'turist rehberliği', 'otelcilik', 'seyahat acenteliği', 'fırıncılık', 'kasaplık',
  'çiçekçilik', 'cankurtaranlık', 'forklift operatörlüğü', 'vinç operatörlüğü',
  'iş makinesi operatörlüğü', 'arıcılık', 'hayvancılık', 'seracılık'
]), 'Hizmet'
union all
select unnest(array[
  'hasta bakımı', 'yaşlı bakımı', 'çocuk bakımı', 'fizyoterapi', 'psikolojik danışmanlık',
  'hemşirelik', 'bebek bakımı', 'pet bakımı', 'evde bakım hizmeti', 'engelli bakımı',
  'refakatçilik', 'konuşma & dil terapisi', 'ergoterapi', 'aile danışmanlığı',
  'diş kliniği asistanlığı', 'eczane teknisyenliği', 'tıbbi sekreterlik',
  'ilk yardım eğitmenliği', 'laborantlık', 'radyoloji teknisyenliği', 'köpek eğitimi',
  'pet kuaförü', 'diş hekimliği', 'eczacılık', 'veterinerlik', 'pratisyen hekimlik',
  'ebelik', 'optisyenlik', 'anestezi teknikerliği', 'ameliyathane teknikerliği',
  'acil tıp teknisyenliği (att)', 'sosyal hizmet uzmanlığı'
]), 'Bakım & Sağlık'
union all
select unnest(array[
  'müzisyenlik', 'ses kayıt', 'seslendirme', 'çeviri', 'organizasyon & etkinlik',
  'müzik prodüksiyonu', 'oyunculuk', 'editörlük & redaksiyon', 'podcast prodüksiyonu',
  'radyo programcılığı', 'dj performansı', 'beste & aranjman', 'mix & mastering',
  'ses tasarımı (sound design)', 'tiyatro', 'dans performansı', 'sunuculuk & moderatörlük',
  'dublaj', 'simultane çeviri', 'yeminli çevirmenlik', 'altyazı çevirisi', 'lokalizasyon',
  'senaryo yazarlığı', 'kitap & e-kitap yazarlığı', 'gazetecilik',
  'kurumsal etkinlik yönetimi', 'fuar organizasyonu', 'konser & sahne organizasyonu',
  'animatörlük (etkinlik)', 'karikatür & çizgi roman'
]), 'Medya & Sanat'
on conflict (tag) do update set category = excluded.category;

-- Deste puanlaması v3 — kategori farkındalıklı + keşif payı
-- (bkz. docs/mvp.md §4.4):
--   6 puan × birebir etiket eşleşmesi (onun yetkinlikleri ∩ benim arayışlarım)
--   2 puan × karşılıklılık (benim yetkinliklerim ∩ onun arayışları)
--   2 puan × ortak kategori (onun yetkinlik kategorileri ∩ benim arayış
--            kategorilerim; kategori başına 1 kez — etiket yığarak şişirilemez)
--   1 puan × karşılıklı ortak kategori
--   +4 puan aynı şehir
-- Keşif payı: destenin ~%80'i puan sırasıyla gelir; her 5. pozisyon
-- (5, 10, 15, ...) keşif kartıdır — en yeni kayıtlı 50 aday arasından
-- rastgele seçilir. Amaç: tekdüzeliği kırmak ve yeni üyelere görünürlük
-- (soğuk başlangıç). random() nedeniyle fonksiyon volatile'dır.
-- Sıralamadır, filtre değildir. Daha önce kaydırılanlar gelmez.
-- Flutter'dan çağrı: supabase.rpc('get_deck')
create or replace function public.get_deck(p_limit int default 20)
returns table (
  id          uuid,
  full_name   text,
  title       text,
  bio         text,
  city        text,
  skills      text[],
  avatar_url  text,
  match_score int
)
language sql
volatile
set search_path = public
as $$
  with me as (
    select p.skills, p.looking_for, p.city
    from public.profiles p
    where p.id = auth.uid()
  ),
  my_seek_cats as (
    select distinct tc.category
    from public.tag_catalog tc, me
    where tc.tag = any(me.looking_for)
  ),
  my_skill_cats as (
    select distinct tc.category
    from public.tag_catalog tc, me
    where tc.tag = any(me.skills)
  ),
  scored as (
    select
      p.id, p.full_name, p.title, p.bio, p.city, p.skills, p.avatar_url,
      p.created_at,
      (
        6 * cardinality(array(select unnest(p.skills)
                              intersect
                              select unnest(me.looking_for)))
      + 2 * cardinality(array(select unnest(me.skills)
                              intersect
                              select unnest(p.looking_for)))
      + 2 * (select count(*) from my_seek_cats c
             where c.category in (select tc.category from public.tag_catalog tc
                                  where tc.tag = any(p.skills)))
      + 1 * (select count(*) from my_skill_cats c
             where c.category in (select tc.category from public.tag_catalog tc
                                  where tc.tag = any(p.looking_for)))
      + case when me.city is not null and p.city = me.city then 4 else 0 end
      )::int as match_score
    from public.profiles p, me
    where p.id <> auth.uid()
      and not exists (
        select 1 from public.swipes s
        where s.swiper_id = auth.uid()
          and s.swiped_id = p.id
      )
  ),
  -- Ana liste: puan sırasıyla, keşif payı düşülmüş kadar
  main as (
    select s.*,
           row_number() over (order by s.match_score desc, s.created_at desc) as rn
    from scored s
    order by s.match_score desc, s.created_at desc
    limit greatest(p_limit - p_limit / 5, 1)
  ),
  -- Keşif: ana listeye girememiş en yeni 50 aday arasından rastgele
  explore as (
    select f.*, row_number() over (order by random()) as rn
    from (
      select s2.*
      from scored s2
      where s2.id not in (select m.id from main m)
      order by s2.created_at desc
      limit 50
    ) f
    order by rn
    limit p_limit / 5
  )
  -- Serpiştirme: ana kartlar sırayla, keşif kartları 5., 10., 15., ... pozisyonda
  select merged.id, merged.full_name, merged.title, merged.bio, merged.city,
         merged.skills, merged.avatar_url, merged.match_score
  from (
    select m.*, (m.rn + (m.rn - 1) / 4) as pos from main m
    union all
    select e.*, (5 * e.rn) as pos from explore e
  ) merged
  order by merged.pos
  limit p_limit
$$;

-- ------------------------------------------------------------
-- 7) DOSYA DEPOLARI (Storage)
-- ------------------------------------------------------------
-- avatars: herkese açık (profil fotoğrafları)
-- cvs    : özel — yalnızca sahibi ve eşleştikleri erişebilir
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('cvs', 'cvs', false)
on conflict (id) do nothing;

-- Dosya yolu kuralı: her kullanıcı yalnızca kendi klasörüne yazar
-- (örn. avatars/{uid}/avatar.jpg, cvs/{uid}/cv.pdf)

-- Avatar deposu herkese açıktır (dosyalar public URL ile indirilir); bu
-- politika API tarafında nesne kaydını okumayı açar. Upsert'lü yükleme ve
-- silme, sunucu içinde önce kaydı okuduğu için select izni de gerektirir.
create policy "Avatar: giriş yapanlar okuyabilir"
  on storage.objects for select to authenticated
  using (bucket_id = 'avatars');

create policy "Avatar: kendi klasörüne yükle"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Avatar: kendi dosyanı güncelle"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Avatar: kendi dosyanı sil"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "CV: kendi klasörüne yükle"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'cvs'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "CV: kendi dosyanı güncelle"
  on storage.objects for update to authenticated
  using (bucket_id = 'cvs'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "CV: kendi dosyanı sil"
  on storage.objects for delete to authenticated
  using (bucket_id = 'cvs'
    and (storage.foldername(name))[1] = auth.uid()::text);

-- CV gizlilik kuralı (docs/mvp.md §4.2): sahibi + eşleştikleri okuyabilir.
-- Uygulama, özel depodaki CV'yi imzalı URL (createSignedUrl) ile açar;
-- imzalı URL üretimi bu select iznine tabidir.
create policy "CV: sahibi ve eşleştikleri okuyabilir"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'cvs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.matches m
        where (m.user1_id = auth.uid()
               and m.user2_id::text = (storage.foldername(name))[1])
           or (m.user2_id = auth.uid()
               and m.user1_id::text = (storage.foldername(name))[1])
      )
    )
  );

-- ============================================================
-- ŞEMA SONU
-- Doğrulama: 4 tablo (profiles, swipes, matches, messages),
-- 1 trigger fonksiyonu, 1 deste fonksiyonu, 2 depo görünmeli.
-- ============================================================
