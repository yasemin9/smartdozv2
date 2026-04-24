BEGIN;



-- 1. Aspirin (Asetilsalisilik Asit - N02BA01)
-- Açıklama ne olursa olsun üzerine yazar.
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Salisilatlar grubuna dahil olan bu bileşik, prostaglandin sentezini inhibe ederek analjezik (ağrı kesici), antipioretik (ateş düşürücü) ve yüksek dozlarda antiinflamatuar (iltihap giderici) etkiler sergiler. Ayrıca, trombositlerdeki siklooksijenaz enzimini geri dönüşümsüz olarak baskılayarak antiagregan (kan sulandırıcı) aktivite gösterir.

KULLANIM ŞEKLİ: Gastrointestinal irritasyonu minimize etmek amacıyla tercihen yemeklerden sonra bol su veya süt ile oral yoldan alınmalıdır. Tabletler parçalanmadan veya çiğnenmeden bütün olarak yutulmalıdır.

DİKKAT EDİLECEKLER: Peptik ülser, gastrointestinal kanama öyküsü veya hemofili gibi koagülasyon bozukluğu olan bireylerde kullanımı kesinlikle kontrendikedir. Çocuklarda Reye Sendromu riski nedeniyle doktora danışılmadan kullanılmamalıdır.'
WHERE atc_code = 'N02BA01';

-- 2. Parasetamol (N02BE01)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Santral sinir sisteminde prostaglandin sentezini öncelikli olarak inhibe ederek güçlü analjezik ve antipioretik etki sağlar. Mide mukozası üzerinde iritasyon yapmaması temel avantajıdır.

KULLANIM ŞEKLİ: Aç veya tok karnına uygulanabilir. Erişkinlerde günlük toplam dozun 4000 mg (4 gram) sınırını aşması ciddi hepatotoksisite (karaciğer hasarı) riskine yol açabilir.

DİKKAT EDİLECEKLER: Kronik alkol kullanımı veya karaciğer yetmezliği olan hastalarda dikkatli kullanılmalıdır. Diğer parasetamol içeren ilaçlarla birleştirilmemelidir.'
WHERE atc_code = 'N02BE01';

-- 3. İbuprofen (M01AE01)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Non-Steroidal Anti-İnflamatuar İlaç (NSAİİ) grubundadır. Post-operatif ağrılar, romatizmal ağrılar ve inflamatuar durumların semptomatik tedavisinde ödem çözücü etkisiyle öne çıkar.

KULLANIM ŞEKLİ: Mide yan etkilerini önlemek için mutlaka yemeklerden sonra veya yemek esnasında alınması tavsiye edilir.

DİKKAT EDİLECEKLER: Kalp-damar hastalığı veya ciddi böbrek fonksiyon bozukluğu olan hastalarda risk oluşturabilir. Hamileliğin son döneminde kullanımı sakıncalıdır.'
WHERE atc_code = 'M01AE01';

UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Periton diyalizi işlemlerinde kullanılan, elektrolit kompozisyonu plazma değerlerine yakın, hipertonik glukoz içeren steril çözeltilerdir. Böbrek yetmezliği olan hastalarda vücuttaki toksik metabolitlerin, suyun ve elektrolitlerin periton zarı aracılığıyla uzaklaştırılmasını (ultrafiltrasyon) sağlar.

KULLANIM ŞEKLİ: Sadece periton diyalizi kateteri aracılığıyla karın boşluğuna uygulanmalıdır. Uygulama öncesi çözelti vücut sıcaklığına getirilmelidir. Değişim sıklığı ve bekletme süresi, hastanın üre klirensi ve ultrafiltrasyon ihtiyacına göre hekim tarafından belirlenir.

DİKKAT EDİLECEKLER: Uygulama sırasında aseptik tekniklere (hijyen kuralları) maksimum özen gösterilmelidir; aksi halde peritonit (karın zarı iltihabı) riski oluşur. Diyabet hastalarında kan şekeri düzeyi yakından takip edilmelidir. Karın içi basınç artışına bağlı fıtık veya nefes darlığı gelişebilir.'
WHERE atc_code LIKE 'B05D%';


UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Vücudun protein sentezi için ihtiyaç duyduğu temel amino asitleri içeren, damar yoluyla uygulanan beslenme çözeltisidir. Oral veya enteral yolla beslenemeyen hastalarda azot dengesini korumak ve beslenme desteği sağlamak amacıyla kullanılır.

KULLANIM ŞEKLİ: Sadece hastane ortamında, santral veya periferik venöz kateter aracılığıyla yavaş infüzyon şeklinde uygulanır. Dozaj, hastanın metabolik durumuna ve protein ihtiyacına göre hekimce belirlenir.

DİKKAT EDİLECEKLER: Ciddi karaciğer veya böbrek yetmezliği olanlarda, amino asit metabolizması bozukluğu olan hastalarda dikkatli kullanılmalıdır. Uygulama sırasında elektrolit ve sıvı dengesi düzenli izlenmelidir.'
WHERE atc_code = 'B05BA03';

-- 2. B05BB01 (Elektrolit Çözeltileri - Sodyum Klorür / İzotonik)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Vücudun kaybettiği su ve tuzu (elektrolitleri) yerine koymak için kullanılan izotonik çözeltidir. Dehidratasyon (sıvı kaybı) tedavisi ve damar yolunun açık tutulması amacıyla kullanılır.

KULLANIM ŞEKLİ: Damar içine (intravenöz) infüzyon yoluyla uygulanır. İnfüzyon hızı hastanın yaşına, kilosuna ve klinik tablosuna göre ayarlanır.

DİKKAT EDİLECEKLER: Hipertansiyon, kalp yetmezliği veya ödemi olan hastalarda sıvı yüklenmesine neden olabileceği için dikkatli olunmalıdır. Sodyum kısıtlaması olan hastalarda hekim kontrolünde kullanılmalıdır.'
WHERE atc_code = 'B05BB01';

-- 3. B05BB02 (Elektrolit Çözeltileri - Ringer Laktat vb.)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Vücut sıvılarına benzer elektrolit konsantrasyonuna sahip dengeli bir çözeltidir. Cerrahi operasyonlar, travma veya yanık gibi durumlarda gelişen sıvı ve elektrolit kayıplarının yerine konmasında etkilidir.

KULLANIM ŞEKLİ: Damar yoluyla infüzyon şeklinde uygulanır. Hastanın asit-baz dengesi ve elektrolit düzeyleri takip edilerek doz ayarlanır.

DİKKAT EDİLECEKLER: Laktat metabolizması bozukluğu olanlarda veya ciddi metabolik alkaloz durumlarında kullanılmamalıdır. Potasyum içerdiği için hiperkalemi riski olan hastalarda takip gerektirir.'
WHERE atc_code = 'B05BB02';

-- 4. B05CX01 (Glukoz Çözeltileri - Dekstroz)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Vücuda kalori (enerji) sağlamak ve sıvı ihtiyacını karşılamak amacıyla kullanılan şeker çözeltisidir. Hipoglisemi (kan şekeri düşüklüğü) durumlarında ve parenteral beslenme rejimlerinin bir parçası olarak kullanılır.

KULLANIM ŞEKLİ: İntravenöz yolla yavaş infüzyon şeklinde uygulanır. Uygulama hızı, hastanın glukoz toleransına göre belirlenmelidir.

DİKKAT EDİLECEKLER: Diyabetik hastalarda ve hiperglisemi durumlarında kontrendikedir. Uzun süreli kullanımda elektrolit eksikliklerine yol açabileceği için elektrolit takibi yapılmalıdır.'
WHERE atc_code = 'B05CX01';

-- 5. C10AA07 (Rosuvastatin - Kolesterol İlacı)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Statin grubuna dahil bir lipid düşürücü ilaçtır. Karaciğerde kolesterol üretimini sağlayan enzimi baskılayarak "kötü" kolesterolü (LDL) düşürür ve kardiyovasküler hastalık riskini minimize eder.

KULLANIM ŞEKLİ: Günde bir kez, günün aynı saatinde, aç veya tok karnına oral yolla alınır. Tedavi süresince kolesterolden fakir bir diyet uygulanması önerilir.

DİKKAT EDİLECEKLER: Açıklanamayan kas ağrıları veya halsizlik durumunda (rabdomiyoliz riski) derhal doktora başvurulmalıdır. Karaciğer fonksiyon testleri düzenli takip edilmelidir. Gebelik ve emzirme döneminde kullanılmamalıdır.'
WHERE atc_code = 'C10AA07';


-- 1. B05XA03 (Hipertonik Sodyum Klorür çözeltileri)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Şiddetli sodyum eksikliği (hiponatremi) ve vücut sıvılarının aşırı kaybı durumlarında elektrolit dengesini hızla yeniden sağlamak için kullanılır. 
KULLANIM ŞEKLİ: Sadece hastane ortamında, kan değerleri (serum sodyum düzeyi) sıkı takip edilerek intravenöz infüzyon yoluyla çok yavaş uygulanır. 
DİKKAT EDİLECEKLER: Hızlı uygulama santral pontin miyelinoliz gibi geri dönüşümsüz sinir sistemi hasarlarına yol açabilir.'
WHERE atc_code = 'B05XA03';

-- 2. N05AH03 (Ketiapin - Örn: Apzet)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Atipik antipsikotik grubundadır. Şizofreni, bipolar bozukluk ve majör depresif bozukluk ataklarının tedavisinde duygu durumunu ve düşünceleri dengelemek için kullanılır. 
KULLANIM ŞEKLİ: Günün aynı saatlerinde, aç veya tok karnına alınabilir. Doz artırımı hekim kontrolünde kademeli yapılmalıdır. 
DİKKAT EDİLECEKLER: Ciddi uykulu hal, baş dönmesi ve kilo artışı yapabilir. Alkolle kullanımı merkezi sinir sistemi baskılanmasını artırır.'
WHERE atc_code = 'N05AH03';

-- 3. R05CB01 (Asetilsistein - Örn: Asist)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Mukolitik (balgam söktürücü) etkilidir. Yoğun kıvamlı balgamı parçalayarak öksürükle atılmasını kolaylaştırır; solunum yollarını temizler. 
KULLANIM ŞEKLİ: Efervesan tabletler bir bardak suda eritilerek içilmelidir. İlacın etkisini artırmak için gün içinde bol sıvı tüketilmesi önerilir. 
DİKKAT EDİLECEKLER: Mide ülseri olanlarda dikkatli kullanılmalıdır. Nadiren bronşlarda daralma veya alerjik reaksiyon yapabilir.'
WHERE atc_code = 'R05CB01';

-- 4. N05AH04 (Klozapin - Örn: Ankep)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Diğer ilaçlara yanıt vermeyen dirençli şizofreni vakalarında kullanılan çok güçlü bir antipsikotiktir. 
KULLANIM ŞEKLİ: Tabletler su ile yutulmalıdır. Tedavi süresince doktorun belirlediği doz şemasına tam uyulması hayatidir. 
DİKKAT EDİLECEKLER: Kandaki beyaz kan hücresi (lökosit) sayısında ani düşüş yapabileceği için düzenli kan tahlili yaptırılması zorunludur.'
WHERE atc_code = 'N05AH04';

-- 5. N03AX16 (Pregabalin - Örn: Lyrica, Gerica)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Nöropatik ağrı (sinir hasarı ağrısı), yaygın kaygı bozukluğu ve epilepsi (sara) nöbetlerinin ek tedavisinde sinir sinyallerini dengelemek için kullanılır. 
KULLANIM ŞEKLİ: Günün her günü aynı saatte, yemekle veya tek başına alınabilir. Tedavi aniden kesilmemelidir. 
DİKKAT EDİLECEKLER: Baş dönmesi, uyku hali ve konsantrasyon bozukluğu yapabilir. Bağımlılık potansiyeli nedeniyle sadece reçete edilen dozda kullanılmalıdır.'
WHERE atc_code = 'N03AX16';

-- 6. C09DA03 (Valsartan ve Diüretik - Örn: Cardopan Plus)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Tansiyon düşürücü iki ajanın kombinasyonudur. Damarları gevşetir ve idrar çıkışını artırarak kan basıncını kontrol altına alır. 
KULLANIM ŞEKLİ: Genellikle sabahları aç veya tok karnına alınır. Düzenli kullanım tansiyon kontrolü için şarttır. 
DİKKAT EDİLECEKLER: Işığa karşı duyarlılık, baş dönmesi veya halsizlik yapabilir. Böbrek fonksiyonları ve potasyum düzeyleri takip edilmelidir.'
WHERE atc_code = 'C09DA03';

-- 7. J01DC02 (Sefuroksim - Örn: Avifur)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: İkinci kuşak sefalosporin antibiyotiktir. Solunum yolları, kulak-burun-boğaz ve üriner sistem enfeksiyonlarında bakterileri yok eder. 
KULLANIM ŞEKLİ: Tablet formları tok karnına alınmalıdır. Damar yolu formları sadece hastanede uygulanır. 
DİKKAT EDİLECEKLER: Penisilin alerjisi olanlarda dikkatli kullanılmalıdır. Antibiyotik direnci oluşmaması için kutu bitene kadar kullanılmalıdır.'
WHERE atc_code = 'J01DC02';

-- 8. N03AX14 (Levetirasetam - Örn: Anlev)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Antiepileptik bir ilaçtır. Epilepsi hastalarında nöbetlerin sıklığını azaltmak ve nöbetleri kontrol altına almak amacıyla kullanılır. 
KULLANIM ŞEKLİ: Dozlar 12 saat arayla, sabah ve akşam düzenli alınmalıdır. Şurup formları ölçekle, tabletler bol suyla tüketilmelidir. 
DİKKAT EDİLECEKLER: Sinirlilik, saldırganlık veya ruh hali değişiklikleri gibi yan etkiler görülürse doktora başvurulmalıdır.'
WHERE atc_code = 'N03AX14';

-- 9. C08CA01 (Amlodipin - Örn: Amlodis)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Kalsiyum kanal blokeridir. Damar duvarlarındaki kasları gevşeterek kanın daha rahat akmasını sağlar; yüksek tansiyon ve göğüs ağrısını (anjina) tedavi eder. 
KULLANIM ŞEKLİ: Günde bir kez, günün aynı saatinde alınmalıdır. Greyfurt suyu ile birlikte tüketilmemelidir. 
DİKKAT EDİLECEKLER: Ayak bileklerinde şişlik (ödem) ve yüz kızarması en yaygın yan etkileridir.'
WHERE atc_code = 'C08CA01';

-- 10. G04BE08 (Tadalafil - Örn: Cialis)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Fosfodiesteraz tip 5 inhibitörüdür. Erektil disfonksiyon (sertleşme sorunu) ve iyi huylu prostat büyümesine bağlı idrar yolu semptomlarının tedavisinde kullanılır. 
KULLANIM ŞEKLİ: İhtiyaçtan en az 30 dakika önce alınmalıdır. Etkisi 36 saate kadar sürebilir. 
DİKKAT EDİLECEKLER: Nitrat içeren kalp ilaçlarıyla birlikte kullanımı ani ve ölümcül tansiyon düşüşüne yol açar. Kalp hastaları çok dikkatli olmalıdır.'
WHERE atc_code = 'G04BE08';

-- 11. N06AB10 (Essitalopram - Örn: Anzyl)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Seçici serotonin geri alım inhibitörü (SSRI) bir antidepresandır. Depresyon, panik atak ve anksiyete bozukluklarının tedavisinde serotonin dengesini sağlar. 
KULLANIM ŞEKLİ: Sabah veya akşam, her gün aynı saatte alınmalıdır. Tam etkinin görülmesi 2-4 hafta sürebilir. 
DİKKAT EDİLECEKLER: İlk haftalarda mide bulantısı veya uyku bozukluğu yapabilir. Doktor onayı olmadan ilaç asla aniden bırakılmamalıdır.'
WHERE atc_code = 'N06AB10';

-- 12. N05AX12 (Aripiprazol - Örn: Abilify)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Atipik antipsikotik ve duygu durum dengeleyicidir. Şizofreni ve bipolar bozukluktaki mani ataklarının tedavisinde kullanılır. 
KULLANIM ŞEKLİ: Aç veya tok karnına uygulanabilir. Düzenli kullanım semptomların geri gelmesini önler. 
DİKKAT EDİLECEKLER: Huzursuzluk, yerinde duramama hali (akatizi) veya titreme yapabilir.'
WHERE atc_code = 'N05AX12';

-- 13. C10AA05 (Atorvastatin - Örn: Amvastan)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Lipid düşürücü bir statindir. Kandaki kolesterol ve trigliserid düzeylerini düşürerek kalp krizi ve inme riskini azaltır. 
KULLANIM ŞEKLİ: Günde bir kez, tercihen akşam saatlerinde alınır. Tedavi sırasında yağdan fakir bir diyet uygulanmalıdır. 
DİKKAT EDİLECEKLER: Beklenmedik kas ağrısı, koyu renkli idrar veya halsizlik durumunda ilaca ara verilip doktora gidilmelidir.'
WHERE atc_code = 'C10AA05';

-- 14. N04BC05 (Pramipeksol - Örn: Pacto, Parim)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Dopamin agonistidir. Parkinson hastalığındaki titreme ve hareket kısıtlılığı ile Huzursuz Bacak Sendromu semptomlarını gidermek için kullanılır. 
KULLANIM ŞEKLİ: Genellikle günde 3 kez alınır. Mide rahatsızlığını önlemek için yemekle alınması önerilir. 
DİKKAT EDİLECEKLER: Gün içinde ani uyku basması veya halüsinasyonlara neden olabilir. Araç kullanımı sırasında dikkatli olunmalıdır.'
WHERE atc_code = 'N04BC05';

-- 15. J01MA02 (Siprofloksasin - Örn: Baysip, Ciflosin)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Geniş spektrumlu bir florokinolon antibiyotiğidir. İdrar yolu, solunum sistemi ve kemik enfeksiyonlarına neden olan bakterileri öldürür. 
KULLANIM ŞEKLİ: Bol su ile tüketilmelidir. Süt ürünleri veya kalsiyumlu takviyelerle aynı anda alınmamalıdır (emilimi azaltır). 
DİKKAT EDİLECEKLER: Tendon hasarı riski nedeniyle kas ağrısı olursa fiziksel aktivite kısıtlanmalı ve doktora haber verilmelidir.'
WHERE atc_code = 'J01MA02';

-- 16. J01DD04 (Seftriakson - Örn: Avisef)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Üçüncü kuşak sefalosporin antibiyotiktir. Menenjit, sepsis ve ciddi cerrahi enfeksiyonlar gibi ağır tablolarda damar veya kas yoluyla kullanılır. 
KULLANIM ŞEKLİ: Sadece sağlık personeli tarafından enjeksiyon yoluyla uygulanır. 
DİKKAT EDİLECEKLER: Safra kesesinde çamurlaşma veya ishal yapabilir. Alerji öyküsü olanlarda test yapılmadan uygulanmamalıdır.'
WHERE atc_code = 'J01DD04';

-- 17. M01AE02 (Naproksen - Örn: A-Nox, Apranax)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Non-steroid antiinflamatuar bir ilaçtır. Kas-iskelet sistemi ağrıları, diş ağrısı ve adet sancılarında ağrı ve iltihabı hızla giderir. 
KULLANIM ŞEKLİ: Mide mukozasını korumak için mutlaka tam tok karnına, bol su ile yutulmalıdır. 
DİKKAT EDİLECEKLER: Mide kanaması riski nedeniyle uzun süreli kontrolsüz kullanımından kaçınılmalıdır. Kalp hastalarında risk oluşturabilir.'
WHERE atc_code = 'M01AE02';


-- 1. R05X (Soğuk Algınlığı Kombinasyonları - Örn: A-Ferin Forte)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Analjezik, antipioretik ve antihistaminik etkilerin kombinasyonudur. Grip ve soğuk algınlığına bağlı ateş, baş ağrısı, burun akıntısı ve hapşırma semptomlarını hızla giderir. 
KULLANIM ŞEKLİ: Yetişkinlerde semptomlar devam ettiği sürece 6 saatte bir, tok karnına bol su ile alınması önerilir. 
DİKKAT EDİLECEKLER: Belirgin bir uyuşukluk yapabilir. Alkolle birlikte kullanılmamalıdır. Prostat büyümesi veya glokomu olanlar doktora danışmalıdır.'
WHERE atc_code = 'R05X';

-- 2. G04BE03 (Sildenafil - Örn: Combo)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Fosfodiesteraz tip 5 inhibitörüdür. Penisteki kan damarlarını gevşeterek kan akışını artırır ve erektil disfonksiyon (sertleşme sorunu) tedavisinde yardımcı olur. 
KULLANIM ŞEKLİ: Cinsel aktiviteden yaklaşık 1 saat önce, günde en fazla bir kez alınmalıdır. Ağır yağlı yemeklerle kullanımı etkisini geciktirebilir. 
DİKKAT EDİLECEKLER: Göğüs ağrısı için "nitrat" içeren ilaç kullananlar kesinlikle kullanmamalıdır; ani ve tehlikeli tansiyon düşüşüne yol açabilir.'
WHERE atc_code = 'G04BE03';

-- 3. N05AX08 (Risperidon - Örn: Neoris, As-Risper)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Atipik antipsikotik grubundadır. Şizofreni, bipolar bozukluğun mani atakları ve çocuklardaki bazı davranış bozukluklarının tedavisinde beyindeki dopamin ve serotonin dengesini sağlar. 
KULLANIM ŞEKLİ: Günlük tek doz veya ikiye bölünmüş dozlar halinde, aç veya tok karnına alınabilir. Oral çözeltiler meyve suyu ile karıştırılabilir (çay hariç). 
DİKKAT EDİLECEKLER: İştah artışı, kilo alımı ve titreme yapabilir. Yaşlı hastalarda dehidratasyon riskine karşı dikkatli olunmalıdır.'
WHERE atc_code = 'N05AX08';

-- 4. J01DD15 (Sefdinir - Örn: Asemax)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Üçüncü kuşak sefalosporin antibiyotiğidir. Sinüzit, zatürre ve deri enfeksiyonlarına neden olan çok çeşitli bakterileri yok eder. 
KULLANIM ŞEKLİ: Aç veya tok karnına alınabilir. Ancak antasitler (mide ilaçları) veya demir takviyeleri ile arasında en az 2 saat bırakılmalıdır. 
DİKKAT EDİLECEKLER: Nadiren dışkı rengini kırmızıya boyayabilir (zararsızdır). İshal veya döküntü görülürse doktora başvurulmalıdır.'
WHERE atc_code = 'J01DD15';

-- 5. R03DC03 (Montelukast - Örn: Clast)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Lökotrien reseptör antagonistidir. Hava yollarındaki daralmayı ve şişliği azaltarak astım semptomlarını kontrol altına alır ve alerjik rinit (saman nezlesi) şikayetlerini giderir. 
KULLANIM ŞEKLİ: Günde bir kez akşamları, tercihen yemeklerden bağımsız olarak çiğneme tableti veya film kaplı tablet formunda alınır. 
DİKKAT EDİLECEKLER: Bu bir "kurtarıcı" ilaç değildir, ani nefes darlığı ataklarında kullanılmaz. Ruh hali değişiklikleri veya uyku bozukluğu yapabilir.'
WHERE atc_code = 'R03DC03';

-- 6. N06DX01 (Memantin - Örn: Angetin)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: NMDA reseptör antagonistidir. Orta ve şiddetli Alzheimer tipi demans hastalarında bellek ve öğrenme fonksiyonlarının korunmasına yardımcı olur. 
KULLANIM ŞEKLİ: Günde bir kez, her gün aynı saatte alınmalıdır. Doz genellikle doktor kontrolünde haftalık olarak artırılır. 
DİKKAT EDİLECEKLER: Baş dönmesi, denge kaybı ve kabızlık yapabilir. Böbrek yetmezliği olanlarda doz ayarlaması gereklidir.'
WHERE atc_code = 'N06DX01';

-- 7. A11CC05 (Kolekalsiferol - D3 Vitamini - Örn: Coledan)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Güçlü bir D3 vitamini takviyesidir. Kalsiyum ve fosfor emilimini düzenleyerek kemik sağlığını korur, bağışıklık sistemini destekler ve kas güçsüzlüğünü önler. 
KULLANIM ŞEKLİ: Genellikle yemeklerle birlikte veya yağlı öğünlerin hemen ardından oral damla veya yumuşak kapsül şeklinde alınır. 
DİKKAT EDİLECEKLER: Kontrolsüz yüksek doz kullanımı kanda kalsiyum birikmesine (hiperkalsemi) ve böbrek taşı riskine yol açabilir.'
WHERE atc_code = 'A11CC05';

-- 8. B05BA10 (Parenteral Beslenme Karışımları)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Karbonhidrat, amino asit ve elektrolit içeren kompleks bir beslenme çözeltisidir. Ağız yoluyla beslenemeyen hastalarda tüm besin ihtiyacını karşılar. 
KULLANIM ŞEKLİ: Sadece hastane ortamında, büyük damarlar (merkezi venöz kateter) üzerinden uzmanlarca uygulanır. 
DİKKAT EDİLECEKLER: Kan şekeri, elektrolitler ve karaciğer fonksiyonları uygulama boyunca yakından takip edilmelidir.'
WHERE atc_code = 'B05BA10';

-- 9. C09DA08 (Olmesartan ve Diüretik - Örn: Calenda Plus)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Anjiyotensin II reseptör blokeri ve bir idrar söktürücünün kombinasyonudur. Tansiyonu düşürür ve vücuttaki fazla tuzu-suyu atarak kalbin yükünü hafifletir. 
KULLANIM ŞEKLİ: Sabahları tek doz, tercihen kahvaltı ile alınması önerilir. 
DİKKAT EDİLECEKLER: Tedavi başında baş dönmesi yapabilir. Şiddetli ve kronik ishal gelişirse (sprue benzeri enteropati) ilaç kesilmeli ve doktora bildirilmelidir.'
WHERE atc_code = 'C09DA08';

-- 10. N02BB02 (Metamizol Sodyum - Örn: Adepiron)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Güçlü bir analjezik ve antipioretiktir. Diğer ağrı kesicilerin yetersiz kaldığı şiddetli post-operatif ağrılar veya yüksek ateşli durumlarda kullanılır. 
KULLANIM ŞEKLİ: Tabletler bol suyla yutulur; şurup ve damla formları çocuklarda kiloya göre ayarlanır. 
DİKKAT EDİLECEKLER: Nadir fakat ciddi bir yan etki olan agranülositoz (beyaz kan hücresi kaybı) riski nedeniyle uzun süreli kullanımı doktor kontrolünde olmalıdır.'
WHERE atc_code = 'N02BB02';

-- 11. C09CA08 (Olmesartan Medoksomil - Örn: Calenda)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Saf tansiyon düşürücü bir ajandır. Damarların daralmasına neden olan hormonu engelleyerek kan basıncını düşürür ve böbrekleri korumaya yardımcı olur. 
KULLANIM ŞEKLİ: Günün aynı saatinde, yemekle veya aç karnına alınabilir. 
DİKKAT EDİLECEKLER: Gebelikte kesinlikle kullanılmamalıdır. Potasyum içeren takviyelerle birlikte kullanımı kanda potasyum yükselmesine yol açabilir.'
WHERE atc_code = 'C09CA08';

-- 12. M03BX05 (Tiyokolşikosid - Örn: Adeleks)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Kas gevşetici etkilidir. İskelet kaslarındaki spazmı (kasılmayı) çözerek bel, boyun ve sırt ağrılarında hareket kısıtlılığını giderir. 
KULLANIM ŞEKLİ: Genellikle günde 2 kez, tok karnına alınır. Tedavi süresi 7 günü aşmamalıdır. 
DİKKAT EDİLECEKLER: Nadiren uyuşukluk veya ishal yapabilir. Epilepsi (sara) geçmişi olanlarda nöbet tetikleme riski nedeniyle dikkatli olunmalıdır.'
WHERE atc_code = 'M03BX05';

-- 13. B05XA30 (Kombine Elektrolit Çözeltileri - Örn: İzoleks)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Vücudun kaybettiği su, elektrolit ve kalori ihtiyacını karşılayan dengeli bir infüzyon çözeltisidir. Ameliyat sonrası veya ağır sıvı kaybında kullanılır. 
KULLANIM ŞEKLİ: Sadece intravenöz (IV) infüzyon yoluyla sağlık profesyonellerince uygulanır. 
DİKKAT EDİLECEKLER: Böbrek yetmezliği veya kalp yetmezliği olanlarda ödem ve akciğer yüklenmesi riskine karşı titizlikle izlenmelidir.'
WHERE atc_code = 'B05XA30';

-- 14. N07BA01 (Nikotin Sakızı/Bandı - Örn: Nicorette)
-- SQL HATASI DÜZELTİLDİ: "SET description =" eklendi.
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Nikotin replasman tedavisidir. Sigarayı bırakma sürecinde oluşan yoksunluk belirtilerini ve sigara içme isteğini hafifleterek bağımlılıktan kurtulmaya yardımcı olur. 
KULLANIM ŞEKLİ: Sakız çiğnenirken nikotin tadı hissedildiğinde yanak içine park edilmeli ve emilimin gerçekleşmesi beklenmelidir. 
DİKKAT EDİLECEKLER: Kalp hastalığı veya ağız içi yaraları olanlar dikkatli kullanmalıdır. Aşırı çiğneme mide yanmasına yol açabilir.'
WHERE atc_code = 'N07BA01';

-- 15. J01CR02 (Amoksisilin + Klavulanik Asit - Örn: Aklav)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Geniş spektrumlu bir antibiyotiktir. Bakterilerin savunma mekanizmasını çökerten yapısıyla orta kulak iltihabı, sinüzit ve diş enfeksiyonlarını tedavi eder. 
KULLANIM ŞEKLİ: Mide-bağırsak yan etkilerini azaltmak için mutlaka yemek başlangıcında alınmalıdır. 
DİKKAT EDİLECEKLER: Penisilin alerjisi olanlarda kullanılmamalıdır. Tedavi süresince gelişen şiddetli ishal mutlaka hekime bildirilmelidir.'
WHERE atc_code = 'J01CR02';

-- 16. J01CA01 (Ampisilin - Örn: Ampisina)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Penisilin grubu bir antibiyotiktir. Çeşitli bakteriyel enfeksiyonların (solunum, idrar yolu, deri) hücre duvarını yıkarak ölmesini sağlar. 
KULLANIM ŞEKLİ: İlacın emilimini artırmak için yemeklerden en az yarım saat önce veya 2 saat sonra (aç karnına) alınmalıdır. 
DİKKAT EDİLECEKLER: Ciltte döküntü veya nefes darlığı gibi alerjik belirtiler görülürse kullanım hemen durdurulmalıdır.'
WHERE atc_code = 'J01CA01';

-- 17. V09FX03 (Radyoaktif İyot - Örn: Mon-iyot)
UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Radyoaktif bir izotoptur. Hipertiroidi (zehirli guatr) tedavisi veya tiroid kanseri dokularının görüntülenmesi/yok edilmesi amacıyla kullanılır. 
KULLANIM ŞEKLİ: Sadece nükleer tıp merkezlerinde, kapsül veya sıvı formda uzman kontrolünde tek doz olarak uygulanır. 
DİKKAT EDİLECEKLER: Uygulama sonrası belirli bir süre çevredeki kişilere radyasyon yaymamak için izolasyon kurallarına (mesafe, hijyen) uyulması zorunludur. Gebelerde kesinlikle yasaktır.'
WHERE atc_code = 'V09FX03';


UPDATE public.global_medications
SET description = 'TEMEL FAYDASI: Vücudun kaybettiği su ve tuzu yerine koymak için kullanılan izotonik çözeltidir. Dehidratasyon tedavisi ve damar yolunun açık tutulması amacıyla kullanılır. 
KULLANIM ŞEKLİ: Damar içine (IV) infüzyon yoluyla uygulanır. İnfüzyon hızı hastanın ihtiyacına göre ayarlanır. 
DİKKAT EDİLECEKLER: Kalp yetmezliği veya ödemi olan hastalarda sıvı yüklenmesine neden olabileceği için dikkatli olunmalıdır.'
WHERE atc_code = '0' 
  AND product_name ILIKE '%IZOTONIK%' 
  AND product_name NOT ILIKE '%HIPERTONIK%';

--!!
  --!DEĞİŞİMSELL

UPDATE public.global_medications
SET atc_code = 'B05BB01'
WHERE atc_code = '0' 
  AND product_name ILIKE '%IZOTONIK%' 
  AND product_name NOT ILIKE '%HIPERTONIK%';

-- 2. Hipertonik (%3) olanların ATC kodunu güncelle
UPDATE public.global_medications
SET atc_code = 'B05XA03'
WHERE atc_code = '0' 
  AND product_name ILIKE '%HIPERTONIK %3%';



UPDATE global_medications 
SET atc_code = 'R05X' 
WHERE product_name LIKE 'A-FERIN%' 
  AND atc_code = '0';

  UPDATE global_medications 
SET atc_code = 'R05X' 
WHERE product_name LIKE 'A-FERİN%' 
  AND atc_code = '0';

UPDATE global_medications 
SET atc_code = 'C01CA24' 
WHERE (product_name LIKE 'ADRENALIN%' OR active_ingredient LIKE '%epinefrin%') 
  AND atc_code = '0';

  
UPDATE global_medications 
SET atc_code = 'R03AK06' 
WHERE product_name LIKE 'ACTİONFLU%' 
  AND atc_code = '0';

UPDATE global_medications 
SET atc_code = 'M01AE09' 
WHERE product_name LIKE 'MAJEZIK %TABLET%' OR product_name LIKE 'MAJEZIK %KAPSUL%'
  AND atc_code = '0';


UPDATE global_medications 
SET atc_code = 'M02AA19' 
WHERE (product_name LIKE '%JEL%' OR product_name LIKE '%SPREY%') 
  AND product_name LIKE 'MAJEZIK%'
  AND atc_code = '0';

UPDATE global_medications 
SET atc_code = 'R02AX01' 
WHERE (product_name LIKE '%GARGARA%' OR product_name LIKE '%ORAL SPREY%')
  AND product_name LIKE 'MAJEZIK%'
  AND atc_code = '0';


UPDATE global_medications SET atc_code = 'N03AX14' WHERE active_ingredient IN ('levetirasetam', 'levetiracetam') AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N05AH04' WHERE active_ingredient LIKE '%ketiapin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N02BF02' WHERE active_ingredient = 'pregabalin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N06DX01' WHERE active_ingredient LIKE '%memantin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'G04BE08' WHERE active_ingredient = 'tadalafil' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J02AC01' WHERE active_ingredient = 'flukonazol' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AE01' WHERE active_ingredient = 'ibuprofen' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AB05' WHERE active_ingredient LIKE '%diklofenak%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AE09' WHERE active_ingredient = 'flurbiprofen' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N06BA04' WHERE active_ingredient LIKE '%metilfenidat%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A10BA02' WHERE active_ingredient LIKE '%metformin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AB05' WHERE active_ingredient LIKE '%diklofenak%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R03DC03' WHERE active_ingredient LIKE '%montelukast%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A10BB09' WHERE active_ingredient LIKE '%gliklazid%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01GB03' WHERE active_ingredient LIKE '%gentamisin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C10AA05' WHERE active_ingredient LIKE '%atorvastatin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N05BA01' WHERE active_ingredient = 'diazepam' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A02BC03' WHERE active_ingredient = 'lansoprazol' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N02BF01' WHERE active_ingredient = 'gabapentin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AE17' WHERE active_ingredient LIKE '%deksketoprofen%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A02BA03' WHERE active_ingredient = 'famotidin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N02BE01' WHERE active_ingredient = 'parasetamol' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01DD15' WHERE active_ingredient = 'sefdinir' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B05BC01' WHERE active_ingredient = 'mannitol' AND atc_code = '0';

UPDATE global_medications 
SET atc_code = 'B05BB02' 
WHERE active_ingredient LIKE '%sodyum klorür%' AND active_ingredient LIKE '%dekstroz%'
  AND atc_code = '0';



UPDATE global_medications SET atc_code = 'J01FA09' WHERE active_ingredient IN ('klaritromisin', 'clarithromycin') AND atc_code = '0';
UPDATE global_medications SET atc_code = 'H03AA01' WHERE active_ingredient LIKE '%levotiroksin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01CR02' WHERE active_ingredient LIKE '%amoksisilin%' AND active_ingredient LIKE '%klavulanik%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N06AB10' WHERE active_ingredient LIKE '%essitalopram%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N06DA02' WHERE active_ingredient LIKE '%donepezil%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01BA01' WHERE active_ingredient = 'kloramfenikol' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AB08' WHERE active_ingredient = 'etodolac' AND atc_code = '0';

UPDATE global_medications SET atc_code = 'A10BB12' WHERE active_ingredient = 'glimepiride' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AC06' WHERE active_ingredient = 'meloksikam' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'V08AB10' WHERE active_ingredient = 'iomeprol' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C09CA04' WHERE active_ingredient = 'irbesartan' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M03BX05' WHERE active_ingredient = 'tiyokolşikosid' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C09CA03' WHERE active_ingredient = 'valsartan' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C09CA01' WHERE active_ingredient = 'losartan potasyum' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N06AB10' WHERE active_ingredient = 'escitalopram' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01DC02' WHERE active_ingredient = 'sefuroksim aksetil' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01DD13' WHERE active_ingredient = 'sefpodoksim proksetil' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01MA12' WHERE active_ingredient = 'levofloksasin hemihidrat' AND atc_code = '0';

UPDATE global_medications SET atc_code = 'A10BF02' WHERE active_ingredient = 'miglitol' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N02BA01' WHERE active_ingredient = 'asetilsalisilik asit' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AE02' WHERE active_ingredient = 'naproksen' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B03XA01' WHERE active_ingredient = 'epoetin zeta' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AB08' WHERE active_ingredient = 'etodolak' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A10BB12' WHERE active_ingredient = 'glimepirid' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01CR02' WHERE active_ingredient = 'amoxicillin and enzyme inhibitor' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01DB04' WHERE active_ingredient = 'cefazolin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R03AC13' WHERE active_ingredient = 'formoterol fumarat dihidrat' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R05CB01' WHERE active_ingredient = 'asetilsistein' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N03AX18' WHERE active_ingredient = 'lakozamid' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C03BA11' WHERE active_ingredient = 'indapamid' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C09DA08' WHERE active_ingredient LIKE 'olmesartan medoksomil ve hidrokloroti%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01FA01' WHERE active_ingredient = 'eritromisin' AND atc_code = '0';


-- S-Etodolak (Ağrı Kesici)
UPDATE global_medications SET atc_code = 'M01AB08' WHERE active_ingredient = 's-etodolak' AND atc_code = '0';

-- Acarbose (Diyabet)
UPDATE global_medications SET atc_code = 'A10BF01' WHERE active_ingredient = 'acarbose' AND atc_code = '0';

-- Feksofenadin HCl (Alerji)
UPDATE global_medications SET atc_code = 'R06AX26' WHERE active_ingredient = 'feksofenadin hcl' AND atc_code = '0';

-- Irbesartan + Hidroklorotiyazid (Tansiyon Kombinasyonu)
UPDATE global_medications SET atc_code = 'C09DA04' WHERE active_ingredient = 'irbesartan, hidroklorotiyazid' AND atc_code = '0';

-- Valsartan + Hidroklorotiyazid (Tansiyon Kombinasyonu)
UPDATE global_medications SET atc_code = 'C09DA03' WHERE active_ingredient = 'valsartan, hidroklorotiyazid' AND atc_code = '0';

-- Amlodipin + Rosuvastatin (Kolesterol ve Tansiyon)
UPDATE global_medications SET atc_code = 'C10BX03' WHERE active_ingredient = 'amlodipin besilat ve rosuvastatin kalsiyum' AND atc_code = '0';

-- Furosemid (Güçlü İdrar Söktürücü - Lasix vb.)
UPDATE global_medications SET atc_code = 'C03CA01' WHERE active_ingredient = 'furosemid' AND atc_code = '0';

-- Iohexol (Kontrast Madde)
UPDATE global_medications SET atc_code = 'V08AB02' WHERE active_ingredient = 'iohexol' AND atc_code = '0';

-- Gliclazide (Diyabet)
UPDATE global_medications SET atc_code = 'A10BB09' WHERE active_ingredient = 'gliclazide' AND atc_code = '0';

-- Linezolid (Güçlü Antibiyotik)
UPDATE global_medications SET atc_code = 'J01XX08' WHERE active_ingredient = 'linezolid' AND atc_code = '0';

-- Meloxicam (Ağrı Kesici)
UPDATE global_medications SET atc_code = 'M01AC06' WHERE active_ingredient = 'meloxicam' AND atc_code = '0';

-- Levofloxacin (Antibiyotik)
UPDATE global_medications SET atc_code = 'J01MA12' WHERE active_ingredient = 'levofloxacin' AND atc_code = '0';


-- Diltiazem HCl (Tansiyon ve Kalp - Diltizem vb.)
UPDATE global_medications SET atc_code = 'C08DB01' WHERE active_ingredient = 'diltiazem hcl' AND atc_code = '0';

-- Sefiksim (Antibiyotik - Zimaks vb.)
UPDATE global_medications SET atc_code = 'J01DD08' WHERE active_ingredient = 'sefiksim' AND atc_code = '0';

-- Desmopressin (Hormon Tedavisi - Minirin vb.)
UPDATE global_medications SET atc_code = 'H01BA02' WHERE active_ingredient = 'desmopressin' AND atc_code = '0';

-- Lidocaine (Yerel Anestezi)
UPDATE global_medications SET atc_code = 'N01BB02' WHERE active_ingredient = 'lidocaine' AND atc_code = '0';

-- Duloksetin HCl (Antidepresan - Duloxx, Cymbalta vb.)
UPDATE global_medications SET atc_code = 'N06AX21' WHERE active_ingredient = 'duloksetin hcl' AND atc_code = '0';

-- Olmesartan Medoksomil (Tansiyon - Olmetec vb.)
UPDATE global_medications SET atc_code = 'C09CA08' WHERE active_ingredient = 'olmesartan medoksomil' AND atc_code = '0';

-- Pioglitazone (Diyabet)
UPDATE global_medications SET atc_code = 'A10BG03' WHERE active_ingredient = 'pioglitazone' AND atc_code = '0';

-- Amikasin (Güçlü Antibiyotik)
UPDATE global_medications SET atc_code = 'J01GB06' WHERE active_ingredient IN ('amikasin', 'amikasin sülfat') AND atc_code = '0';

-- Metilprednizolon Aseponat (Kortikosteroid - Advantan vb.)
UPDATE global_medications SET atc_code = 'D07AC14' WHERE active_ingredient = 'metilprednizolon aseponat' AND atc_code = '0';

-- Indometazin (Ağrı Kesici / Antiinflamatuar - Endol vb.)
UPDATE global_medications SET atc_code = 'M01AB01' WHERE active_ingredient = 'indometazin' AND atc_code = '0';



-- Gentamicin (Antibiyotik)
UPDATE global_medications SET atc_code = 'J01GB03' WHERE active_ingredient = 'gentamicin' AND atc_code = '0';

-- Valsartan + Hidroklorotiyazid (Tansiyon Kombinasyonu - Farklı yazım)
UPDATE global_medications SET atc_code = 'C09DA03' WHERE active_ingredient = 'valsartan + hidroklorotiyazid' AND atc_code = '0';

-- Amikacin (Antibiyotik - Farklı yazım)
UPDATE global_medications SET atc_code = 'J01GB06' WHERE active_ingredient = 'amikacin' AND atc_code = '0';

-- Amoksisilin (Antibiyotik)
UPDATE global_medications SET atc_code = 'J01CA04' WHERE active_ingredient = 'amoksisilin' AND atc_code = '0';

-- Fluconazole (Mantar İlacı - Farklı yazım)
UPDATE global_medications SET atc_code = 'J02AC01' WHERE active_ingredient = 'fluconazole' AND atc_code = '0';

-- Mometazon Furoat (Kortikosteroid Sprey - Nazonex vb.)
UPDATE global_medications SET atc_code = 'R01AD09' WHERE active_ingredient = 'mometazon furoat' AND atc_code = '0';

-- Deferasiroks (Demir Şelatörü - Exjade vb.)
UPDATE global_medications SET atc_code = 'V03AC03' WHERE active_ingredient = 'deferasiroks' AND atc_code = '0';

-- Desloratadin (Alerji İlacı - Aerius vb.)
UPDATE global_medications SET atc_code = 'R06AX27' WHERE active_ingredient = 'desloratadin' AND atc_code = '0';

-- Budesonid (Astim/KOAH - Pulmicort vb.)
UPDATE global_medications SET atc_code = 'R03BA02' WHERE active_ingredient = 'budesonid' AND atc_code = '0';

-- Vildagliptin (Diyabet - Galvus vb.)
UPDATE global_medications SET atc_code = 'A10BH02' WHERE active_ingredient = 'vildagliptin' AND atc_code = '0';

-- Eritromisin Estolat (Antibiyotik varyasyonu)
UPDATE global_medications SET atc_code = 'J01FA01' WHERE active_ingredient = 'eritromisin estolat' AND atc_code = '0';


-- Naproksen Sodyum (Ağrı Kesici - Apranax vb.)
UPDATE global_medications SET atc_code = 'M01AE02' WHERE active_ingredient = 'naproksen sodyum' AND atc_code = '0';

-- Pioglitazon (Diyabet)
UPDATE global_medications SET atc_code = 'A10BG03' WHERE active_ingredient IN ('pioglitazon', 'pioglitazon hidroklorür') AND atc_code = '0';

-- Sildenafil Sitrat (Viagra vb.)
UPDATE global_medications SET atc_code = 'G04BE03' WHERE active_ingredient = 'sildenafil sitrat' AND atc_code = '0';

-- Etofenamat (Ağrı Kesici Jel/Sprey - Flexo vb.)
UPDATE global_medications SET atc_code = 'M02AA06' WHERE active_ingredient = 'etofenamat' AND atc_code = '0';

-- Formoterol ve Budesonid (Astım/KOAH Kombinasyonu - Symbicort vb.)
UPDATE global_medications SET atc_code = 'R03AK07' WHERE active_ingredient = 'formoterol fumarat dihidrat ve budesonid' AND atc_code = '0';

-- Metamizol Sodyum (Ağrı Kesici - Novalgin vb.)
UPDATE global_medications SET atc_code = 'N02BB02' WHERE active_ingredient = 'metamizol sodyum' AND atc_code = '0';

-- Zolmitriptan (Migren İlacı - Zomig vb.)
UPDATE global_medications SET atc_code = 'N02CC03' WHERE active_ingredient = 'zolmitriptan' AND atc_code = '0';

-- Losartan + Hidroklorotiyazid (Tansiyon Kombinasyonu - Hyzaar vb.)
UPDATE global_medications SET atc_code = 'C09DA01' WHERE active_ingredient = 'losartan potasyum, hidroklorotiyazid' AND atc_code = '0';

-- Aciclovir (Antiviral - Aklovir, Zovirax vb.)
UPDATE global_medications SET atc_code = 'J05AB01' WHERE active_ingredient = 'aciclovir' AND atc_code = '0';

-- Telmisartan + Hidroklorotiyazid (Tansiyon Kombinasyonu - MicardisPlus vb.)
UPDATE global_medications SET atc_code = 'C09DA07' WHERE active_ingredient = 'telmisartan+hidroklorotiyazid' AND atc_code = '0';

-- Erythropoietin (Anemi Tedavisi)
UPDATE global_medications SET atc_code = 'B03XA01' WHERE active_ingredient = 'erythropoietin' AND atc_code = '0';

-- Pioglitazon HCl (Diyabet)
UPDATE global_medications SET atc_code = 'A10BG03' WHERE active_ingredient = 'pioglitazon hcl' AND atc_code = '0';

-- Simetikon (Gaz Giderici - Metsil vb.)
UPDATE global_medications SET atc_code = 'A03AX13' WHERE active_ingredient = 'simetikon' AND atc_code = '0';

-- Clindamycin (Antibiyotik - Cleocin vb.)
UPDATE global_medications SET atc_code = 'J01FF01' WHERE active_ingredient = 'clindamycin' AND atc_code = '0';

-- Cefpodoxime (Antibiyotik - Infex vb.)
UPDATE global_medications SET atc_code = 'J01DD13' WHERE active_ingredient = 'cefpodoxime' AND atc_code = '0';

-- Iopamidol (Kontrast Madde)
UPDATE global_medications SET atc_code = 'V08AB03' WHERE active_ingredient = 'lopamidol' AND atc_code = '0';

-- Kalsiyum Asetat (Fosfat Bağlayıcı)
UPDATE global_medications SET atc_code = 'V03AE07' WHERE active_ingredient = 'kalsiyum asetat' AND atc_code = '0';

-- Rivastigmin Hidrojen Tartarat (Alzheimer İlacı - Exelon vb.)
UPDATE global_medications SET atc_code = 'N06DA03' WHERE active_ingredient = 'rivastigmin hidrojen tartarat' AND atc_code = '0';

-- Adrenalin (Epinefrin)
UPDATE global_medications SET atc_code = 'C01CA24' WHERE active_ingredient = 'adrenalin' AND atc_code = '0';

-- Esomeprazol Sodyum (Mide Koruyucu - Nexium vb.)
UPDATE global_medications SET atc_code = 'A02BC05' WHERE active_ingredient = 'esomeprazol sodyum' AND atc_code = '0';

-- Saflaştırılmış Hepatit B Yüzey Antijeni (Aşı)
UPDATE global_medications SET atc_code = 'J07BC01' WHERE active_ingredient = 'saflaştırılmış hepatit b yüzey antijeni' AND atc_code = '0';

-- Amoxicillin (Antibiyotik)
UPDATE global_medications SET atc_code = 'J01CA04' WHERE active_ingredient = 'amoxicillin' AND atc_code = '0';



-- Saflaştırılmış Hepatit B Yüzey Antijeni (Aşı)
UPDATE global_medications SET atc_code = 'J07BC01' WHERE active_ingredient = 'saflaştırılmış hepatit b yüzey antijeni' AND atc_code = '0';

-- Sodyum Fusidat (Antibiyotik - Fucidin vb.)
UPDATE global_medications SET atc_code = 'J01CF01' WHERE active_ingredient = 'sodyum fusidat' AND atc_code = '0';

-- Rosuvastatin ve Ezetimib (Kolesterol Kombinasyonu - Rosuzet vb.)
UPDATE global_medications SET atc_code = 'C10BA06' WHERE active_ingredient = 'rosuvastatin ve ezetimib' AND atc_code = '0';

-- Ezetimib ve Simvastatin (Kolesterol Kombinasyonu - Inegy vb.)
UPDATE global_medications SET atc_code = 'C10BA02' WHERE active_ingredient = 'ezetimib ve simvastatin' AND atc_code = '0';

-- Arformoterol Tartarat / Budesonid (Astım/KOAH Kombinasyonu)
UPDATE global_medications SET atc_code = 'R03AK' WHERE active_ingredient = 'arformoterol tartarat/budesonid' AND atc_code = '0';

-- Iopamidol (Kontrast Madde - Farklı yazım kontrolü)
UPDATE global_medications SET atc_code = 'V08AB03' WHERE active_ingredient = 'iopamidol' AND atc_code = '0';

-- Granisetron (Bulantı Önleyici - Kytril vb.)
UPDATE global_medications SET atc_code = 'A04AA02' WHERE active_ingredient = 'granisetron' AND atc_code = '0';

-- Valetamat Bromür (Spazm Çözücü - Holit vb.)
UPDATE global_medications SET atc_code = 'A03BA' WHERE active_ingredient = 'valetamat bromür' AND atc_code = '0';

-- Sulpiride (Antipsikotik/Depresyon - Sülpir vb.)
UPDATE global_medications SET atc_code = 'N05AL01' WHERE active_ingredient = 'sulpiride' AND atc_code = '0';

-- Losartan + Hidroklorotiyazid (Tansiyon - Farklı yazım)
UPDATE global_medications SET atc_code = 'C09DA01' WHERE active_ingredient = 'losartan potasyum/hidroklorotiyazid' AND atc_code = '0';

-- Ketoprofen (Ağrı Kesici - Fastjel vb.)
UPDATE global_medications SET atc_code = 'M01AE03' WHERE active_ingredient = 'ketoprofen' AND atc_code = '0';

-- Sefdinir Kombinasyonu (Antibiyotik)
UPDATE global_medications SET atc_code = 'J01DD15' WHERE active_ingredient LIKE 'sefdinir, potasyum klavulanat%' AND atc_code = '0';

-- Flutikazon Propiyonat (Alerji/Astım - Flixonase vb.)
UPDATE global_medications SET atc_code = 'R01AD08' WHERE active_ingredient = 'flutikazon propiyonat' AND atc_code = '0';

-- Benzidamin + Klorheksidin (Boğaz Spreyi/Gargara - Tanflex, Andorex vb.)
UPDATE global_medications SET atc_code = 'A01AD11' WHERE active_ingredient = 'benzidamin hidroklorür, klorheksidin glukonat' AND atc_code = '0';

-- Dekstroz (Şekerli Serum - Farklı varyasyonlar)
UPDATE global_medications SET atc_code = 'B05BA03' WHERE active_ingredient IN ('dekstroz', 'dekstroz monohidrat') AND atc_code = '0';

-- Lornoksikam (Ağrı Kesici - Xefo vb.)
UPDATE global_medications SET atc_code = 'M01AC05' WHERE active_ingredient = 'lornoksikam' AND atc_code = '0';

-- Acetylcysteine (Balgam Söktürücü - İngilizce yazım)
UPDATE global_medications SET atc_code = 'R05CB01' WHERE active_ingredient = 'acetylcysteine' AND atc_code = '0';

-- Butamirat Sitrat (Öksürük Şurubu - Sinecod vb.)
UPDATE global_medications SET atc_code = 'R05DB13' WHERE active_ingredient = 'butamirat sitrat' AND atc_code = '0';

-- Sultamicillin (Antibiyotik - Duocid vb.)
UPDATE global_medications SET atc_code = 'J01CR04' WHERE active_ingredient = 'sultamicillin' AND atc_code = '0';


-- Spironolakton + Hidroklorotiyazid (Tansiyon/Ödem - Aldactazide vb.)
UPDATE global_medications SET atc_code = 'C03EA01' WHERE active_ingredient = 'spironolakton+hidroklorotiyazid' AND atc_code = '0';

-- Formoterol and Budesonid (Astım/KOAH - İngilizce yazım)
UPDATE global_medications SET atc_code = 'R03AK07' WHERE active_ingredient = 'formoterol and budesonid' AND atc_code = '0';

-- Cobamamide (B12 Vitamini türevi)
UPDATE global_medications SET atc_code = 'B03BA04' WHERE active_ingredient = 'cobamamide' AND atc_code = '0';

-- Aripiprazol (Antipsikotik - Abilify vb.)
UPDATE global_medications SET atc_code = 'N05AX12' WHERE active_ingredient IN ('aripiprazol monohidrat', 'aripiprazole') AND atc_code = '0';

-- Karbamazepin (Epilepsi/Bipolar - Tegretol vb.)
UPDATE global_medications SET atc_code = 'N03AF01' WHERE active_ingredient = 'karbamazepin' AND atc_code = '0';

-- Kalsiyum Karbonat (Antiasit/Takviye)
UPDATE global_medications SET atc_code = 'A12AA04' WHERE active_ingredient = 'kalsiyum karbonat' AND atc_code = '0';

-- Klindamisin (Antibiyotik - Türkçe yazım)
UPDATE global_medications SET atc_code = 'J01FF01' WHERE active_ingredient = 'klindamisin' AND atc_code = '0';

-- Eritropoietin Alfa (Anemi - Eprex vb.)
UPDATE global_medications SET atc_code = 'B03XA01' WHERE active_ingredient = 'eritropoietin alfa' AND atc_code = '0';

-- Ofloksasin (Antibiyotik - Tarivid vb.)
UPDATE global_medications SET atc_code = 'J01MA01' WHERE active_ingredient = 'ofloksasin' AND atc_code = '0';

-- Entekavir (Hepatit B - Baraclude vb.)
UPDATE global_medications SET atc_code = 'J05AF10' WHERE active_ingredient = 'entekavir' AND atc_code = '0';

-- B6 Vitamini (Piridoksin)
UPDATE global_medications SET atc_code = 'A11HA02' WHERE active_ingredient = 'b6 vitamini' AND atc_code = '0';

-- Granisetron HCl (Bulantı Önleyici - Farklı yazımlar)
UPDATE global_medications SET atc_code = 'A04AA02' WHERE active_ingredient IN ('granisetron hcl', 'granisetron hidroklorür') AND atc_code = '0';

-- Sefuroksim (Antibiyotik - Aksef vb.)
UPDATE global_medications SET atc_code = 'J01DC02' WHERE active_ingredient IN ('sefuroksim sodyum', 'cefuroxime') AND atc_code = '0';

-- Duloksetin Hidroklorür (Antidepresan - Farklı yazım)
UPDATE global_medications SET atc_code = 'N06AX21' WHERE active_ingredient = 'duloksetin hidroklorür' AND atc_code = '0';

-- Kalsiyum Dobesilat (Vazoprotektif - Doxium vb.)
UPDATE global_medications SET atc_code = 'C05CX01' WHERE active_ingredient = 'kalsiyum dobesilat monohidrat' AND atc_code = '0';

-- Metoksi polietilen glikol/epoetin beta (Anemi - Mircera vb.)
UPDATE global_medications SET atc_code = 'B03XA03' WHERE active_ingredient = 'metoksi polietilen glikol/epoetin beta' AND atc_code = '0';

-- Polidokanol (Lokal Anestezik/Sklerozan)
UPDATE global_medications SET atc_code = 'D11AF' WHERE active_ingredient = 'polidokanol' AND atc_code = '0';

-- Nadroparin (Kan Sulandırıcı - Fraxiparine vb.)
UPDATE global_medications SET atc_code = 'B01AB06' WHERE active_ingredient = 'nadroparin' AND atc_code = '0';

-- Esomeprazol Magnezyum Dihidrat (Mide Koruyucu - Nexium varyasyonu)
UPDATE global_medications SET atc_code = 'A02BC05' WHERE active_ingredient = 'esomeprazol magnezyum dihidrat' AND atc_code = '0';

-- Loratadin (Alerji - Claritine vb.)
UPDATE global_medications SET atc_code = 'R06AX13' WHERE active_ingredient = 'loratadin' AND atc_code = '0';


-- Verapamil (Kalp/Tansiyon - Isoptin vb.)
UPDATE global_medications SET atc_code = 'C08DA01' WHERE active_ingredient = 'verapamil' AND atc_code = '0';

-- Enalapril (Tansiyon - Enapril vb.)
UPDATE global_medications SET atc_code = 'C09AA02' WHERE active_ingredient = 'enalapril' AND atc_code = '0';

-- Sisaprid (Mide/Bağırsak Hareketliliği)
UPDATE global_medications SET atc_code = 'A03FA02' WHERE active_ingredient = 'sisaprid' AND atc_code = '0';

-- Mirtazapin (Antidepresan - Remeron vb.)
UPDATE global_medications SET atc_code = 'N06AX11' WHERE active_ingredient = 'mirtazapin' AND atc_code = '0';

-- Karvedilol (Kalp Yetmezliği/Tansiyon - Dilatrend vb.)
UPDATE global_medications SET atc_code = 'C07AG02' WHERE active_ingredient = 'karvedilol' AND atc_code = '0';

-- Sefprozil (Antibiyotik - Serafzil vb.)
UPDATE global_medications SET atc_code = 'J01DC10' WHERE active_ingredient = 'sefprozil' AND atc_code = '0';

-- Alfa Lipoik Asit (Antioksidan/Nöropati - Thioctacid vb.)
UPDATE global_medications SET atc_code = 'A16AX01' WHERE active_ingredient = 'alfa lipoik asit (tioktik asit)' AND atc_code = '0';

-- Sertraline (Antidepresan - Lustral vb.)
UPDATE global_medications SET atc_code = 'N06AB06' WHERE active_ingredient = 'sertraline' AND atc_code = '0';

-- Levodopa Kombinasyonu (Parkinson - Stalevo vb.)
UPDATE global_medications SET atc_code = 'N04BA03' WHERE active_ingredient = 'levodopa, karbidopa monohidrat, entakapon' AND atc_code = '0';

-- Alendronat (Kemik Erimesi - Fosamax vb.)
UPDATE global_medications SET atc_code = 'M05BA04' WHERE active_ingredient = 'alendronat' AND atc_code = '0';

-- Atropin Sülfat (Antikolinerjik)
UPDATE global_medications SET atc_code = 'A03BA01' WHERE active_ingredient = 'atropin sülfat' AND atc_code = '0';

-- Soğuk Algınlığı Kombinasyonu (A-ferin vb. benzeri içerik)
UPDATE global_medications SET atc_code = 'R05X' WHERE active_ingredient = 'parasetamol, psödoefedrin hcl, klorfeniramin maleat' AND atc_code = '0';

-- Pethidine (Şiddetli Ağrı - Yeşil/Kırmızı Reçete)
UPDATE global_medications SET atc_code = 'N02AB02' WHERE active_ingredient = 'pethidine' AND atc_code = '0';

-- Levosetirizin (Alerji - Xyzal vb.)
UPDATE global_medications SET atc_code = 'R06AE09' WHERE active_ingredient = 'levosetirizin dihidroklorür' AND atc_code = '0';

-- Ketoconazole (Mantar - Nizoral vb.)
UPDATE global_medications SET atc_code = 'J02AC03' WHERE active_ingredient = 'ketoconazole' AND atc_code = '0';


-- Rosuvastatin Kalsiyum (Kolesterol - Crestor vb.)
UPDATE global_medications SET atc_code = 'C10AA07' WHERE active_ingredient = 'rosuvastatin kalsiyum' AND atc_code = '0';

-- Gadodiamid (MR Kontrast Maddesi)
UPDATE global_medications SET atc_code = 'V08CA03' WHERE active_ingredient = 'gadodiamid' AND atc_code = '0';

-- Loratadine (Alerji - İngilizce yazım)
UPDATE global_medications SET atc_code = 'R06AX13' WHERE active_ingredient = 'loratadine' AND atc_code = '0';

-- Lamotrijin (Epilepsi/Bipolar - Lamictal vb.)
UPDATE global_medications SET atc_code = 'N03AX09' WHERE active_ingredient = 'lamotrijin' AND atc_code = '0';

-- S-Amlodipin Besilat (Tansiyon)
UPDATE global_medications SET atc_code = 'C08CA01' WHERE active_ingredient = 's-amlodipin besilat' AND atc_code = '0';

-- Telmisartan (Tansiyon - Micardis vb.)
UPDATE global_medications SET atc_code = 'C09CA07' WHERE active_ingredient = 'telmisartan' AND atc_code = '0';

-- Parnaparin (Kan Sulandırıcı - Fluxum vb.)
UPDATE global_medications SET atc_code = 'B01AB07' WHERE active_ingredient = 'parnaparin' AND atc_code = '0';

-- Eplerenon (Kalp Yetmezliği/Tansiyon - Inspra vb.)
UPDATE global_medications SET atc_code = 'C03DA04' WHERE active_ingredient = 'eplerenon' AND atc_code = '0';

-- Repaglinide (Diyabet - Novonorm vb.)
UPDATE global_medications SET atc_code = 'A10BX02' WHERE active_ingredient = 'repaglinide' AND atc_code = '0';

-- Esomeprazol Magnezyum Trihidrat (Mide Koruyucu)
UPDATE global_medications SET atc_code = 'A02BC05' WHERE active_ingredient = 'esomeprazol magnezyum trihidrat' AND atc_code = '0';

-- Meropenem Trihidrat (Güçlü Antibiyotik - Meronem vb.)
UPDATE global_medications SET atc_code = 'J01DH02' WHERE active_ingredient = 'meropenem trihidrat' AND atc_code = '0';

-- Nateglinid (Diyabet - Starlix vb.)
UPDATE global_medications SET atc_code = 'A10BX03' WHERE active_ingredient = 'nateglinid' AND atc_code = '0';

-- İzoniyazid (Tüberküloz İlacı)
UPDATE global_medications SET atc_code = 'J04AC01' WHERE active_ingredient = 'izoniyazid' AND atc_code = '0';


-- Dexketoprofen (Ağrı Kesici - Arveles vb.)
UPDATE global_medications SET atc_code = 'M01AE17' WHERE active_ingredient = 'dexketoprofen' AND atc_code = '0';

-- Sulfamethoxazole ve Trimethoprim (Antibiyotik - Baktrim vb.)
UPDATE global_medications SET atc_code = 'J01EE01' WHERE active_ingredient = 'sulfamethoxazole and trimethoprim' AND atc_code = '0';

-- Ampicillin (Antibiyotik)
UPDATE global_medications SET atc_code = 'J01CA01' WHERE active_ingredient = 'ampicillin' AND atc_code = '0';

-- Alendronat Sodyum Trihidrat (Kemik Erimesi)
UPDATE global_medications SET atc_code = 'M05BA04' WHERE active_ingredient = 'alendronat sodyum trihidrat' AND atc_code = '0';

-- Demir III Hidroksit Polimaltoz Kompleksi (Demir Takviyesi - Ferrum vb.)
UPDATE global_medications SET atc_code = 'B03AB05' WHERE active_ingredient = 'demir iii hidroksit polimaltoz kompleksi' AND atc_code = '0';

-- Ebastin (Alerji - Kestine vb.)
UPDATE global_medications SET atc_code = 'R06AX22' WHERE active_ingredient = 'ebastin' AND atc_code = '0';

-- Nifuroxazide (İshal Tedavisi - Ercefuryl vb.)
UPDATE global_medications SET atc_code = 'A07AX03' WHERE active_ingredient = 'nifuroxazide' AND atc_code = '0';

-- Bilastin (Alerji - Bilaxen vb.)
UPDATE global_medications SET atc_code = 'R06AX29' WHERE active_ingredient = 'bilastin' AND atc_code = '0';

-- Enalapril Maleat (Tansiyon)
UPDATE global_medications SET atc_code = 'C09AA02' WHERE active_ingredient = 'enalapril maleat' AND atc_code = '0';

-- Seftriakson (Güçlü Antibiyotik - Iespor, Rocephin vb.)
UPDATE global_medications SET atc_code = 'J01DD04' WHERE active_ingredient = 'ceftriaxone' AND atc_code = '0';

-- Deksametazon (Kortizon - Dekort vb.)
UPDATE global_medications SET atc_code = 'H02AB02' WHERE active_ingredient = 'deksametazon' AND atc_code = '0';

-- Hydrocortisone Butyrate (Kortizonlu Krem - Locoid vb.)
UPDATE global_medications SET atc_code = 'D07AB02' WHERE active_ingredient = 'hydrocortisone butyrate' AND atc_code = '0';

-- Methylergometrine (Doğum Sonu Kanama Kontrolü - Methergin vb.)
UPDATE global_medications SET atc_code = 'G02AB01' WHERE active_ingredient = 'methylergometrine' AND atc_code = '0';

-- Solifenasin Süksinat (Veziküler Tedavi - Kinzy, Vesicare vb.)
UPDATE global_medications SET atc_code = 'G04BD08' WHERE active_ingredient = 'solifenasin süksinat' AND atc_code = '0';

-- Mometasone (Kortizon - Farklı yazım)
UPDATE global_medications SET atc_code = 'R01AD09' WHERE active_ingredient = 'mometasone' AND atc_code = '0';

-- Lamivudine (Antiviral - Hepatit B/HIV)
UPDATE global_medications SET atc_code = 'J05AF05' WHERE active_ingredient = 'lamivudine' AND atc_code = '0';

-- Amlodipin Besilat (Tansiyon - Norvasc vb.)
UPDATE global_medications SET atc_code = 'C08CA01' WHERE active_ingredient = 'amlodipin besilat' AND atc_code = '0';

-- Akarboz (Diyabet - Glucobay vb. - Türkçe yazım)
UPDATE global_medications SET atc_code = 'A10BF01' WHERE active_ingredient = 'akarboz' AND atc_code = '0';

-- Dapoksetin Hidroklorür (Erken Boşalma Tedavisi - Priligy vb.)
UPDATE global_medications SET atc_code = 'G04BE09' WHERE active_ingredient = 'dapoksetin hidroklorür' AND atc_code = '0';

-- Triamsinolon Asetonid (Kortizon - Kenacort vb.)
UPDATE global_medications SET atc_code = 'H02AB08' WHERE active_ingredient = 'triamsinolon asetonid' AND atc_code = '0';


-- Saflaştırılmış Hepatit B Yüzey Antijeni (Aşı)
UPDATE global_medications SET atc_code = 'J07BC01' WHERE active_ingredient = 'saflaştırılmış hepatit b yüzey antijeni' AND atc_code = '0';

-- Spironolakton + Hidroklorotiyazid (Tansiyon/Ödem - Farklı yazım)
UPDATE global_medications SET atc_code = 'C03EA01' WHERE active_ingredient = 'spironolakton+hidroklorotiyazid' AND atc_code = '0';

-- Monobazik Sodyum Fosfat / Dibazik Sodyum Fosfat (Lavman/Bağırsak Temizliği - BTM vb.)
UPDATE global_medications SET atc_code = 'A06AD17' WHERE active_ingredient LIKE 'monobazik sodyum fosfat%' AND atc_code = '0';

-- Levodopa + Karbidopa + Entakapon (Parkinson - Farklı yazım)
UPDATE global_medications SET atc_code = 'N04BA03' WHERE active_ingredient = 'levodopa+karbidopa+entakapon' AND atc_code = '0';

-- Pirantel Pamoat (Bağırsak Kurdu - Kontil vb.)
UPDATE global_medications SET atc_code = 'P02CC01' WHERE active_ingredient = 'pirantel pamoat' AND atc_code = '0';

-- Human Menopausal Gonadotrophin (Kısırlık Tedavisi - Menogon vb.)
UPDATE global_medications SET atc_code = 'G03GA02' WHERE active_ingredient = 'human menopausal gonadotrophin' AND atc_code = '0';

-- Kalsiyum Karbonat ve Vitamin D3 (Kemik Sağlığı Takviyesi)
UPDATE global_medications SET atc_code = 'A12AX' WHERE active_ingredient = 'kalsiyum karbonat ve vitamin d3' AND atc_code = '0';

-- Terbinafin (Mantar Tedavisi - Terbisil vb.)
UPDATE global_medications SET atc_code = 'D01AE15' WHERE active_ingredient = 'terbinafin' AND atc_code = '0';

-- Esomeprazol (Mide Koruyucu - Saf hali)
UPDATE global_medications SET atc_code = 'A02BC05' WHERE active_ingredient = 'esomeprazol' AND atc_code = '0';

-- Benzidamin + Klorheksidin (Boğaz Spreyi - Farklı yazım)
UPDATE global_medications SET atc_code = 'A01AD11' WHERE active_ingredient = 'benzidamin hidroklorür, klorheksidin diglukonat' AND atc_code = '0';

-- Apiksaban (Kan Sulandırıcı - Eliquis vb.)
UPDATE global_medications SET atc_code = 'B01AF02' WHERE active_ingredient = 'apiksaban' AND atc_code = '0';

-- Diltiazem Hidroklorür (Kalp/Tansiyon - Diltizem vb.)
UPDATE global_medications SET atc_code = 'C08DB01' WHERE active_ingredient = 'diltiazem hidroklorür' AND atc_code = '0';

-- Glibenklamid (Diyabet - Diyaben vb.)
UPDATE global_medications SET atc_code = 'A10BB01' WHERE active_ingredient = 'glibenklamid' AND atc_code = '0';

-- Sodyum Bikarbonat ve Tartarik Asit (Mide Asidi/Efervesan)
UPDATE global_medications SET atc_code = 'A02AD01' WHERE active_ingredient = 'sodyum bikarbonat ve tartarik asit' AND atc_code = '0';

-- Setirizin Dihidroklorür (Alerji - Allerset, Zyrtec vb.)
UPDATE global_medications SET atc_code = 'R06AE07' WHERE active_ingredient = 'setirizin dihidroklorür' AND atc_code = '0';

-- Venlafaksin (Antidepresan - Efexor vb.)
UPDATE global_medications SET atc_code = 'N06AX16' WHERE active_ingredient = 'venlafaksin' AND atc_code = '0';

-- Rosuvastatin (Kolesterol - Saf hali)
UPDATE global_medications SET atc_code = 'C10AA07' WHERE active_ingredient = 'rosuvastatin' AND atc_code = '0';

-- Amilorid HCl (Potasyum Tutucu Diüretik)
UPDATE global_medications SET atc_code = 'C03DB01' WHERE active_ingredient = 'amilorid hcl' AND atc_code = '0';

-- Ibandronat Sodyum (Kemik Erimesi - Bonviva vb.)
UPDATE global_medications SET atc_code = 'M05BA06' WHERE active_ingredient = 'ibandronat sodyum' AND atc_code = '0';

-- Soğuk Algınlığı Kombinasyonu (Parasetamol + Fenilnefrin + Klorfeniramin)
UPDATE global_medications SET atc_code = 'R05X' WHERE active_ingredient = 'parasetamol, fenilnefrin hcl ve kloreniramin maleat' AND atc_code = '0';

-- Sefaklor (Antibiyotik - Ceclor vb.)
UPDATE global_medications SET atc_code = 'J01DC04' WHERE active_ingredient = 'sefaklor' AND atc_code = '0';

-- Ginkgo Biloba Ekstresi (Hafıza/Dolaşım Takviyesi)
UPDATE global_medications SET atc_code = 'N06DX02' WHERE active_ingredient = 'ginkgo biloba yaprakları kuru ekstresi' AND atc_code = '0';


-- Lamotrigine (Epilepsi - İngilizce yazım)
UPDATE global_medications SET atc_code = 'N03AX09' WHERE active_ingredient = 'lamotrigine' AND atc_code = '0';

-- Ambroksol (Balgam Söktürücü - Mucosolvan vb.)
UPDATE global_medications SET atc_code = 'R05CB06' WHERE active_ingredient = 'ambroxol' AND atc_code = '0';

-- Lamivudin (Antiviral - Türkçe yazım)
UPDATE global_medications SET atc_code = 'J05AF05' WHERE active_ingredient = 'lamivudin' AND atc_code = '0';

-- Sefiksim Kombinasyonu (Antibiyotik)
UPDATE global_medications SET atc_code = 'J01DD08' WHERE active_ingredient LIKE 'sefiksim trihidrat%' AND atc_code = '0';

-- Sultamisilin Tosilat (Antibiyotik - Duocid vb.)
UPDATE global_medications SET atc_code = 'J01CR04' WHERE active_ingredient = 'sultamisilin tosilat' AND atc_code = '0';

-- Maprotilin HCl (Antidepresan - Ludiomil vb.)
UPDATE global_medications SET atc_code = 'N06AA21' WHERE active_ingredient = 'maprotilin hcl' AND atc_code = '0';

-- Levodropropizin (Öksürük Şurubu - Perebron vb.)
UPDATE global_medications SET atc_code = 'R05DB27' WHERE active_ingredient = 'levodropropizin' AND atc_code = '0';

-- Paliperidon (Antipsikotik - Invega vb.)
UPDATE global_medications SET atc_code = 'N05AX13' WHERE active_ingredient = 'paliperidon' AND atc_code = '0';

-- Rofekoksib (Ağrı Kesici - Vioxx vb.)
UPDATE global_medications SET atc_code = 'M01AH02' WHERE active_ingredient = 'rofekoksib' AND atc_code = '0';

-- Ezetimib (Kolesterol)
UPDATE global_medications SET atc_code = 'C10AX09' WHERE active_ingredient = 'ezetimib' AND atc_code = '0';

-- Amlodipin Maleat (Tansiyon varyasyonu)
UPDATE global_medications SET atc_code = 'C08CA01' WHERE active_ingredient = 'amlodipin maleat' AND atc_code = '0';

-- Flutikazon (Alerji/Astım)
UPDATE global_medications SET atc_code = 'R01AD08' WHERE active_ingredient = 'flutikazon' AND atc_code = '0';

-- Mirtazapine (Antidepresan - İngilizce yazım)
UPDATE global_medications SET atc_code = 'N06AX11' WHERE active_ingredient = 'mirtazapine' AND atc_code = '0';

-- Ampisilin + Sulbaktam (Antibiyotik - Duobak vb.)
UPDATE global_medications SET atc_code = 'J01CR01' WHERE active_ingredient = 'Ampisilin, sulbaktam' AND atc_code = '0';

-- Olmesartan + Hidroklorotiyazid (Tansiyon Kombinasyonu)
UPDATE global_medications SET atc_code = 'C09DA08' WHERE active_ingredient = 'olmesartan medoksomil/hidroklorotiyazid' AND atc_code = '0';

-- Simvastatin (Kolesterol - Zocor vb.)
UPDATE global_medications SET atc_code = 'C10AA01' WHERE active_ingredient = 'simvastatin' AND atc_code = '0';

-- Enoxaparin (Kan Sulandırıcı - Clexane vb.)
UPDATE global_medications SET atc_code = 'B01AB05' WHERE active_ingredient = 'enoxaparin' AND atc_code = '0';

-- Somatropin (Büyüme Hormonu - Genotropin vb.)
UPDATE global_medications SET atc_code = 'H01AC01' WHERE active_ingredient = 'somatropin' AND atc_code = '0';

-- Kolestiramin (Kolesterol/Safra Asidi Bağlayıcı - Cholestagel vb.)
UPDATE global_medications SET atc_code = 'C10AC01' WHERE active_ingredient = 'kolestiramin' AND atc_code = '0';

-- Sitagliptin Fosfat Monohidrat (Diyabet - Januvia vb.)
UPDATE global_medications SET atc_code = 'A10BH01' WHERE active_ingredient = 'sitagliptin fosfat monohidrat' AND atc_code = '0';

-- Atomoksetin Hidroklorür (DEHB - Strattera vb.)
UPDATE global_medications SET atc_code = 'N06BA09' WHERE active_ingredient = 'atomoksetin hidroklörür' AND atc_code = '0';


-- 1. Saf Sodyum Klorür (İzotonik / %0.9 NaCl)
UPDATE global_medications 
SET atc_code = 'B05CB01' 
WHERE active_ingredient = 'sodyum klorür' 
  AND atc_code = '0';

-- 2. Sodyum Klorür + Dekstroz Kombinasyonları (Şekerli Tuzlu Serumlar)
-- Listenin üst sıralarındaki "dekstroz/ sodyum laktat/sodyum" gibi karmaşık isimleri yakalar.
UPDATE global_medications 
SET atc_code = 'B05BB02' 
WHERE active_ingredient LIKE '%sodyum klorür%' 
  AND active_ingredient LIKE '%dekstroz%'
  AND atc_code = '0';

-- 3. Diğer Çoklu Elektrolit Çözeltileri (Ringer Laktat vb.)
-- Listenin 4, 5 ve 6. satırlarındaki o çok uzun metinleri (asetat, laktat, potasyum içerenler) hedefler.
UPDATE global_medications 
SET atc_code = 'B05BB01' 
WHERE active_ingredient LIKE '%sodyum laktat%' 
   OR active_ingredient LIKE '%sodyum asetat%'
   OR active_ingredient LIKE '%potasyum klorür%'
  AND atc_code = '0';



-- Spironolakton + Hidroklorotiyazid (Tansiyon - Yazım farkı)
UPDATE global_medications SET atc_code = 'C03EA01' WHERE active_ingredient = 'spironolakton+hidroklorotiyazit' AND atc_code = '0';

-- Metiltestosteron (Hormon)
UPDATE global_medications SET atc_code = 'G03BA02' WHERE active_ingredient = 'metiltestosteron' AND atc_code = '0';

-- Pamidronat Disodyum (Kemik Erimesi/Kanser - Aredia vb.)
UPDATE global_medications SET atc_code = 'M05BA03' WHERE active_ingredient = 'pamidronat disodyum' AND atc_code = '0';

-- Topiramat (Epilepsi/Migren - Topamax vb.)
UPDATE global_medications SET atc_code = 'N03AX11' WHERE active_ingredient = 'topiramat' AND atc_code = '0';

-- Potasyum Iyodür (Tiroid/Radyasyon Koruması)
UPDATE global_medications SET atc_code = 'V03AB21' WHERE active_ingredient = 'potasyum iyodür' AND atc_code = '0';

-- Glibenclamide (Diyabet - İngilizce yazım)
UPDATE global_medications SET atc_code = 'A10BB01' WHERE active_ingredient = 'glibenclamide' AND atc_code = '0';

-- Dobutamine (Kalp Yetmezliği - Damardan)
UPDATE global_medications SET atc_code = 'C01CA07' WHERE active_ingredient = 'dobutamine' AND atc_code = '0';

-- Cefotaxime (Antibiyotik - Sefotak vb.)
UPDATE global_medications SET atc_code = 'J01DD01' WHERE active_ingredient = 'cefotaxime' AND atc_code = '0';

-- Midazolam (Sedasyon/Uyutucu - Dormicum vb.)
UPDATE global_medications SET atc_code = 'N05CD08' WHERE active_ingredient = 'midazolam' AND atc_code = '0';

-- Nebivolol HCl (Tansiyon - Vasoxen vb.)
UPDATE global_medications SET atc_code = 'C07AB12' WHERE active_ingredient = 'nebivolol hcl' AND atc_code = '0';

-- Haloperidol (Antipsikotik - Norodol vb.)
UPDATE global_medications SET atc_code = 'N05AD01' WHERE active_ingredient = 'haloperidol' AND atc_code = '0';

-- Ampisilin + Sulbaktam (Antibiyotik - Farklı yazım)
UPDATE global_medications SET atc_code = 'J01CR01' WHERE active_ingredient = 'ampicillin, sulbaktam' AND atc_code = '0';

-- Demir III Polimaltoz Kompleksi (İngilizce yazım)
UPDATE global_medications SET atc_code = 'B03AB05' WHERE active_ingredient = 'ferric oxide polymaltose complexes' AND atc_code = '0';

-- Sertralin Hidroklorür (Antidepresan - Türkçe yazım)
UPDATE global_medications SET atc_code = 'N06AB06' WHERE active_ingredient = 'sertralin hidroklorür' AND atc_code = '0';

-- Allopurinol (Ürik Asit/Gut - Ürikoliz vb.)
UPDATE global_medications SET atc_code = 'M04AA01' WHERE active_ingredient = 'allopurinol' AND atc_code = '0';

-- Askorbik Asit (C Vitamini)
UPDATE global_medications SET atc_code = 'A11G' WHERE active_ingredient = 'askorbik asit (vit c)' AND atc_code = '0';

-- Flumazenil (Anestezi Panzehiri - Anexate vb.)
UPDATE global_medications SET atc_code = 'V03AB25' WHERE active_ingredient = 'flumazenil' AND atc_code = '0';

-- Soğuk Algınlığı (Ibuprofen/Psödoefedrin/C Vitamini)
UPDATE global_medications SET atc_code = 'R05X' WHERE active_ingredient LIKE 'ibuprofen/psödoefedrin%' AND atc_code = '0';

-- Kolistimetat Sodyum (Güçlü Antibiyotik - Colimycin vb.)
UPDATE global_medications SET atc_code = 'J01XB01' WHERE active_ingredient = 'kolistimetat sodyum' AND atc_code = '0';


-- Dekstroz Anhidrat (Şekerli Serum)
UPDATE global_medications 
SET atc_code = 'B05BA03' 
WHERE active_ingredient = 'dekstroz anhidrat' AND atc_code = '0';

-- Amino Acids (Parenteral Beslenme)
UPDATE global_medications 
SET atc_code = 'B05BA01' 
WHERE active_ingredient = 'amino acids' AND atc_code = '0';

-- Levofloksasin Hemihidrat
UPDATE global_medications 
SET atc_code = 'J01MA12' 
WHERE active_ingredient = 'levofloksasin hemihidrat' AND atc_code = '0';

-- Sultamisilin
UPDATE global_medications 
SET atc_code = 'J01CR04' 
WHERE active_ingredient = 'sultamisilin' AND atc_code = '0';

-- Atomoksetin
UPDATE global_medications 
SET atc_code = 'N06BA09' 
WHERE active_ingredient = 'atomoksetin hidroklörür' AND atc_code = '0';

-- Dihidroksialüminyum Sodyum Karbonat
UPDATE global_medications 
SET atc_code = 'A02AD04' 
WHERE active_ingredient = 'dihydroxialumini sodium carbonate' AND atc_code = '0';

-- İnsan Albümini
UPDATE global_medications 
SET atc_code = 'B05AA01' 
WHERE active_ingredient IN ('insan albumini', 'albumin') AND atc_code = '0';

-- Nifuratel + Nistatin (Kombinasyon - DOĞRU)
UPDATE global_medications 
SET atc_code = 'G01AA51' 
WHERE active_ingredient = 'nifuratel/nistatin' AND atc_code = '0';

-- Edetates (EN DOĞRU YAKLAŞIM - en yaygın form seçildi)
UPDATE global_medications 
SET atc_code = 'V03AZ01' 
WHERE active_ingredient = 'edetates' AND atc_code = '0';

-- combinations (çok genel → ATC verilemez, elle bırak)
-- UPDATE yapılmadı

-- Saflaştırılmış Hepatit B yüzey antijeni (aşı)
UPDATE global_medications 
SET atc_code = 'J07BC01'
WHERE active_ingredient = 'saflaştırılmış hepatit b yüzey antijeni' AND atc_code = '0';

-- Sodyum sakarin + sodyum siklamat
UPDATE global_medications 
SET atc_code = 'V06DX'
WHERE active_ingredient = 'sodyum sakarin ve sodyum siklamat' AND atc_code = '0';

-- Carbohydrates
UPDATE global_medications 
SET atc_code = 'B05BA03'
WHERE active_ingredient = 'carbohydrates' AND atc_code = '0';

-- Electrolytes with carbohydrates
UPDATE global_medications 
SET atc_code = 'A07CA'
WHERE active_ingredient = 'electrolytes with carbohydrates' AND atc_code = '0';

-- Levofloksasin (yazım hatalı ama DB’ye dokunmuyoruz)
UPDATE global_medications 
SET atc_code = 'J01MA12'
WHERE active_ingredient = 'levofloksasin hermihidrat' AND atc_code = '0';

-- Albendazol
UPDATE global_medications 
SET atc_code = 'P02CA03'
WHERE active_ingredient = 'albendazol' AND atc_code = '0';

-- Elektrolit kombinasyonu (IV sıvılar)
UPDATE global_medications 
SET atc_code = 'B05BB01'
WHERE active_ingredient = 'Kalsiyum klorür dihidrat, Potasyum klorür, Sodyum' AND atc_code = '0';

-- Olanzapin
UPDATE global_medications 
SET atc_code = 'N05AH03'
WHERE active_ingredient = 'olanzapin' AND atc_code = '0';

-- Gentamisin sülfat
UPDATE global_medications 
SET atc_code = 'J01GB03'
WHERE active_ingredient = 'gentamicin sülfat' AND atc_code = '0';

-- Atomoksetin
UPDATE global_medications 
SET atc_code = 'N06BA09'
WHERE active_ingredient = 'atomoksetin hidroklorür' AND atc_code = '0';

-- Klopidogrel + Aspirin
UPDATE global_medications 
SET atc_code = 'B01AC30'
WHERE active_ingredient = 'klopidogrel, asetil salisilik asit' AND atc_code = '0';

-- Folik asit
UPDATE global_medications 
SET atc_code = 'B03BB01'
WHERE active_ingredient = 'folik asit' AND atc_code = '0';

-- Metilprednizolon
UPDATE global_medications 
SET atc_code = 'H02AB04'
WHERE active_ingredient = 'metilprednisolon aseponat' AND atc_code = '0';

-- Levocetirizine
UPDATE global_medications 
SET atc_code = 'R06AE09'
WHERE active_ingredient = 'levocetirizine' AND atc_code = '0';

-- Nimesulid
UPDATE global_medications 
SET atc_code = 'M01AX17'
WHERE active_ingredient = 'nimesulid' AND atc_code = '0';

-- Irbesartan + Amlodipin
UPDATE global_medications 
SET atc_code = 'C09DB05'
WHERE active_ingredient = 'irbesartan + amlodipin' AND atc_code = '0';

-- Cefaclor
UPDATE global_medications 
SET atc_code = 'J01DC04'
WHERE active_ingredient = 'cefaclor' AND atc_code = '0';

-- Parasetamol + Kafein
UPDATE global_medications 
SET atc_code = 'N02BE51'
WHERE active_ingredient = 'parasetamol, kafein' AND atc_code = '0';

-- Fenofibrat
UPDATE global_medications 
SET atc_code = 'C10AB05'
WHERE active_ingredient = 'fenofibrat' AND atc_code = '0';

-- INSULIN LISPRO MIX
UPDATE global_medications SET atc_code = 'A10AD04'
WHERE active_ingredient IN (
'% 25 insülin lispro çözelti, % 75 protamin süspansiyon',
'% 25 insülin lispro, % 75 insülin lispro protamin',
'% 50 insülin lispro çözelti, % 50 protamin süspansiyon',
'% 50 insülin lispro, % 50 insülin lispro protamin'
) AND atc_code = '0';

-- FDG
UPDATE global_medications SET atc_code = 'V09IX04'
WHERE active_ingredient = '(18 f)florodeoksiglukoz' AND atc_code = '0';

-- AMINO ACID SOLUTIONS
UPDATE global_medications SET atc_code = 'B05BA01'
WHERE active_ingredient IN (
'Amino asit solüsyonu',
'amino acids, incl. combinations with polypeptides',
'aminoasit kompleksi'
) AND atc_code = '0';

-- DEFERASIROX
UPDATE global_medications SET atc_code = 'V03AC03'
WHERE active_ingredient = 'Deferasiroks' AND atc_code = '0';

-- DEXAMETHASONE
UPDATE global_medications SET atc_code = 'H02AB02'
WHERE active_ingredient IN (
'Deksametazon sodyum fosfat',
'deksametazon sodyum fosfat',
'deksametazon sodyum'
) AND atc_code = '0';

-- DIPHENOXYLATE + ATROPINE
UPDATE global_medications SET atc_code = 'A07DA52'
WHERE active_ingredient = 'Diphenoxylate + atropin sülfat' AND atc_code = '0';

-- DONEPEZIL
UPDATE global_medications SET atc_code = 'N06DA02'
WHERE active_ingredient = 'Donepezil hidroklorür' AND atc_code = '0';

-- CALCIUM FOLINATE
UPDATE global_medications SET atc_code = 'V03AF03'
WHERE active_ingredient IN ('Kalsiyum folinat','calcium folinate') AND atc_code = '0';

-- CLOZAPINE
UPDATE global_medications SET atc_code = 'N05AH02'
WHERE active_ingredient = 'Klozapin' AND atc_code = '0';

-- LOSARTAN
UPDATE global_medications SET atc_code = 'C09CA01'
WHERE active_ingredient = 'Losartan Potasyum' AND atc_code = '0';

-- RIVASTIGMINE
UPDATE global_medications SET atc_code = 'N06DA03'
WHERE active_ingredient IN ('Rivastigmin','rivastigmine') AND atc_code = '0';

-- SPIRONOLACTONE
UPDATE global_medications SET atc_code = 'C03DA01'
WHERE active_ingredient = 'Spironolakton' AND atc_code = '0';

-- ADAPALENE
UPDATE global_medications SET atc_code = 'D10AD03'
WHERE active_ingredient = 'adapalen' AND atc_code = '0';

-- ADEFOVIR
UPDATE global_medications SET atc_code = 'J05AF08'
WHERE active_ingredient = 'adefovir dipivoksil' AND atc_code = '0';

-- ALENDRONATE
UPDATE global_medications SET atc_code = 'M05BA04'
WHERE active_ingredient IN (
'alendronik asit',
'alendronat monosodyum trihidrat'
) AND atc_code = '0';

-- ALPROSTADIL
UPDATE global_medications SET atc_code = 'C01EA01'
WHERE active_ingredient = 'alprostadil' AND atc_code = '0';

-- AMIODARONE
UPDATE global_medications SET atc_code = 'C01BD01'
WHERE active_ingredient = 'amiadoron hcl' AND atc_code = '0';

-- AMIKACIN
UPDATE global_medications SET atc_code = 'J01GB06'
WHERE active_ingredient = 'amikacin sülfat' AND atc_code = '0';

-- AMLODIPINE
UPDATE global_medications SET atc_code = 'C08CA01'
WHERE active_ingredient = 'amlodipin' AND atc_code = '0';

-- AMOXICILLIN
UPDATE global_medications SET atc_code = 'J01CA04'
WHERE active_ingredient = 'amoksisilin trihidrat' AND atc_code = '0';

-- AMPICILLIN + SULBACTAM
UPDATE global_medications SET atc_code = 'J01CR01'
WHERE active_ingredient IN (
'ampicillin sodyum, sulbaktam',
'ampisilin, sulbaktam'
) AND atc_code = '0';

-- ANIDULAFUNGIN
UPDATE global_medications SET atc_code = 'J02AX06'
WHERE active_ingredient = 'anidulafungin' AND atc_code = '0';

-- ARIPIPRAZOLE
UPDATE global_medications SET atc_code = 'N05AX12'
WHERE active_ingredient IN ('aripiprazol','aripirazol monohidrat') AND atc_code = '0';

-- ASPIRIN
UPDATE global_medications SET atc_code = 'N02BA01'
WHERE active_ingredient IN (
'asetil salisik asit',
'asetil salisilik asit'
) AND atc_code = '0';

-- ACETYLCYSTEINE
UPDATE global_medications SET atc_code = 'R05CB01'
WHERE active_ingredient = 'asetil sistein' AND atc_code = '0';

-- ACICLOVIR
UPDATE global_medications SET atc_code = 'J05AB01'
WHERE active_ingredient = 'asiklovir' AND atc_code = '0';

-- AZITHROMYCIN
UPDATE global_medications SET atc_code = 'J01FA10'
WHERE active_ingredient = 'azitromisin dihidrat' AND atc_code = '0';

-- BUDESONIDE + FORMOTEROL
UPDATE global_medications SET atc_code = 'R03AK07'
WHERE active_ingredient = 'budesonid/formoterol fumarat dihidrat' AND atc_code = '0';

-- BISOPROLOL
UPDATE global_medications SET atc_code = 'C07AB07'
WHERE active_ingredient = 'bisoprolol fumarat' AND atc_code = '0';

-- CEFTRIAXONE
UPDATE global_medications SET atc_code = 'J01DD04'
WHERE active_ingredient = 'ceftriaxone disodyum' AND atc_code = '0';

-- CIPROFLOXACIN
UPDATE global_medications SET atc_code = 'J01MA02'
WHERE active_ingredient = 'ciprofloxacin' AND atc_code = '0';

-- CITALOPRAM
UPDATE global_medications SET atc_code = 'N06AB04'
WHERE active_ingredient = 'citalopram' AND atc_code = '0';

-- DAPAGLIFLOZIN
UPDATE global_medications SET atc_code = 'A10BK01'
WHERE active_ingredient = 'dapagliflozin propandiol  monohidrat' AND atc_code = '0';

-- DICLOFENAC
UPDATE global_medications SET atc_code = 'M01AB05'
WHERE active_ingredient = 'diclofenak sodyum' AND atc_code = '0';

-- DIGOXIN
UPDATE global_medications SET atc_code = 'C01AA05'
WHERE active_ingredient IN ('digoksin','digoxin') AND atc_code = '0';

-- DILTIAZEM
UPDATE global_medications SET atc_code = 'C08DB01'
WHERE active_ingredient IN ('diltiazem','diltizem hcl') AND atc_code = '0';


UPDATE global_medications
SET atc_code = 
CASE
    -- PARASETAMOL COMBO
    WHEN active_ingredient ILIKE '%parasetamol%' AND active_ingredient ILIKE '%kafein%' THEN 'N02BE51'

    -- IBUPROFEN COMBO
    WHEN active_ingredient ILIKE '%ibuprofen%' AND active_ingredient ILIKE '%psödoefedrin%' THEN 'M01AE51'

    -- LOSARTAN + HCT
    WHEN active_ingredient ILIKE '%losartan%' AND active_ingredient ILIKE '%hidroklorotiyazid%' THEN 'C09DA01'

    -- VALSARTAN + AMLODIPINE
    WHEN active_ingredient ILIKE '%valsartan%' AND active_ingredient ILIKE '%amlodipin%' THEN 'C09DB01'

    -- PPI + DOMPERIDONE
    WHEN active_ingredient ILIKE '%prazol%' AND active_ingredient ILIKE '%domperidon%' THEN 'A02BC'

    ELSE atc_code
END
WHERE atc_code = '0';


BEGIN; -- Önce işlem bloğunu başlatıyoruz

-- ANTİBİYOTİKLER
UPDATE global_medications SET atc_code = 'J01FA01' WHERE active_ingredient = 'eritromisin base' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01DD02' WHERE active_ingredient = 'ceftazidime' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01DB01' WHERE active_ingredient = 'cefalexin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01DD15' WHERE active_ingredient = 'cefdinir' AND atc_code = '0';

-- Klavulanat riskliydi, Amoksisilin ile olan en yaygın formu (Augmentin vb.) olarak sabitledik
UPDATE global_medications SET atc_code = 'J01CR02' WHERE active_ingredient LIKE '%amoksisilin%' AND active_ingredient LIKE '%klavulan%' AND atc_code = '0';

UPDATE global_medications SET atc_code = 'J01EE01' WHERE active_ingredient IN ('sülfametoksazol trimetoprim','trimetoprim, sulfametoksazol') AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01XA01' WHERE active_ingredient LIKE '%vankomisin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01MA14' WHERE active_ingredient LIKE '%moksifloksasin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01MA01' WHERE active_ingredient LIKE '%ofloxacin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01GB01' WHERE active_ingredient LIKE '%gentamicin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01AA02' WHERE active_ingredient LIKE '%doksisiklin%' AND atc_code = '0';

-- ANTİFUNGAL (Parantez hatasını düzelttim)
UPDATE global_medications SET atc_code = 'J02AC01' WHERE (active_ingredient LIKE '%flukonazol%' OR active_ingredient LIKE '%fluconazole%') AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J02AC02' WHERE active_ingredient LIKE '%itrakonazol%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'D01AC02' WHERE active_ingredient LIKE '%mikonazol%' AND atc_code = '0';

-- HORMON / ENDOKRİN
UPDATE global_medications SET atc_code = 'H03AA01' WHERE active_ingredient LIKE '%levotiroksin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'H01BA02' WHERE active_ingredient LIKE '%desmopressin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'G03CA03' WHERE active_ingredient LIKE '%estradiol%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'G03DA04' WHERE active_ingredient LIKE '%progesteron%' AND atc_code = '0';

-- DİYABET
UPDATE global_medications SET atc_code = 'A10BA02' WHERE active_ingredient LIKE '%metformin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A10BB12' WHERE active_ingredient LIKE '%glimepirid%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A10AB04' WHERE active_ingredient LIKE '%insulin lispro%' AND atc_code = '0';

-- KARDİYOVASKÜLER
UPDATE global_medications SET atc_code = 'C09AA05' WHERE active_ingredient LIKE '%ramipril%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C07AB02' WHERE active_ingredient LIKE '%metoprolol%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C10AA01' WHERE active_ingredient LIKE '%simvastatin%' AND atc_code = '0';

-- AĞRI / NSAID
UPDATE global_medications SET atc_code = 'M01AE01' WHERE active_ingredient LIKE '%ibuprofen%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N02AX02' WHERE active_ingredient LIKE '%tramadol%' AND atc_code = '0';

-- GASTRO
UPDATE global_medications SET atc_code = 'A02BC01' WHERE active_ingredient LIKE '%omeprazol%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A02BC02' WHERE active_ingredient LIKE '%pantoprazol%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A03FA03' WHERE active_ingredient LIKE '%domperidon%' AND atc_code = '0';

-- VİTAMİNLER (Parantezleri ekledim, daha güvenli oldu)
UPDATE global_medications SET atc_code = 'A11CC05' WHERE (active_ingredient LIKE '%vitamin d3%' OR active_ingredient LIKE '%kolekalsiferol%') AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A11HA02' WHERE active_ingredient LIKE '%b6%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A11GA01' WHERE active_ingredient LIKE '%askorbik asit%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A11AA03' WHERE active_ingredient LIKE '%multivitamin%' AND atc_code = '0'; -- Daha genel bir koda çektik

-- ELEKTROLİTLER
UPDATE global_medications SET atc_code = 'B05XA03' WHERE active_ingredient LIKE '%potasyum klorür%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B05XA05' WHERE active_ingredient LIKE '%magnezyum sülfat%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B05XA02' WHERE active_ingredient LIKE '%sodyum bikarbonat%' AND atc_code = '0';

-- SOLUNUM
UPDATE global_medications SET atc_code = 'R03AC02' WHERE active_ingredient LIKE '%salbutamol%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R06AE07' WHERE active_ingredient LIKE '%cetirizin%' AND atc_code = '0';

-- DİĞER
UPDATE global_medications SET atc_code = 'N06AB10' WHERE active_ingredient LIKE '%escitalopram%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N03AX16' WHERE active_ingredient LIKE '%pregabalin%' AND atc_code = '0';

COMMIT; -- Her şey yolundaysa kaydet



BEGIN;

-- 1. Tansiyon Kombinasyonları (Irbesartan ve Enalapril Grupları)
UPDATE global_medications SET atc_code = 'C09DA04' WHERE active_ingredient ILIKE '%irbesartan%hidroklorotiyazid%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C09DB05' WHERE active_ingredient ILIKE '%irbesartan%amlodipin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C09AA02' WHERE active_ingredient = 'enalapril hcl' AND atc_code = '0';

-- 2. Serumlar ve Uzun İsimli Karışımlar
-- Alt satırdaki LIKE sorguları o çok uzun, virgüllü serum isimlerini yakalayacaktır.
UPDATE global_medications SET atc_code = 'B05BB01' WHERE (active_ingredient LIKE '%Sodyum asetat%' OR active_ingredient LIKE '%Dekstroz anhidr%' OR active_ingredient LIKE '%Kalsiyum klorür dihidrat%') AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B05BA02' WHERE active_ingredient = 'fat emulsions' AND atc_code = '0';

-- 3. Diyabet ve İnsülin
UPDATE global_medications SET atc_code = 'A10AB01' WHERE active_ingredient = 'insulin (human)' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A10BF03' WHERE active_ingredient = 'vogliboz' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A10BJ05' WHERE active_ingredient = 'liksisenatid' AND atc_code = '0';

-- 4. Hormon ve Vitamin
UPDATE global_medications SET atc_code = 'G03GA02' WHERE active_ingredient IN ('menotropin hp', 'follitropin alfa') AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A11HA03' WHERE active_ingredient ILIKE '%tokoferol%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B03BA01' WHERE active_ingredient = 'siyanokobalamin' AND atc_code = '0';

-- 5. Diğer Kritik İlaçlar
UPDATE global_medications SET atc_code = 'B01AC04' WHERE active_ingredient = 'klopidogrel bisülfat' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'H05BX01' WHERE active_ingredient = 'sinakalset' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R05CB15' WHERE active_ingredient = 'erdostein' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N05CD08' WHERE active_ingredient = 'midazolam hidroklorür' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C10AA08' WHERE active_ingredient = 'pitavastatin kalsiyum' AND atc_code = '0';

COMMIT;


BEGIN;

-- 1. Astım ve Solunum (Çok kritik - Fostair, Advair vb.)
UPDATE global_medications SET atc_code = 'R03AK06' WHERE active_ingredient ILIKE '%salmeterol%flutikazon%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R03AK07' WHERE active_ingredient ILIKE '%formoterol%budesonid%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R03BC01' WHERE active_ingredient = 'cromoglicic acid' AND atc_code = '0';

-- 2. Ağrı ve Anestezi (Kırmızı Reçete Grubu)
UPDATE global_medications SET atc_code = 'N02AB03' WHERE active_ingredient = 'fentanil' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'G04BE08' WHERE active_ingredient = 'vardenafil' AND atc_code = '0';

-- 3. Mide ve Bağırsak (Lactulose ve Glukozamin)
UPDATE global_medications SET atc_code = 'A06AD11' WHERE active_ingredient = 'lactulose' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M01AX05' WHERE active_ingredient ILIKE 'glukozamin sulfat%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A03BA02' WHERE active_ingredient = 'oksifensiklimin hcl' AND atc_code = '0';

-- 4. Demir ve Kan Ürünleri
UPDATE global_medications SET atc_code = 'B03AB05' WHERE active_ingredient = 'demir protein süksinilat' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B01AA07' WHERE active_ingredient = 'sülfasalazin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B02BD02' WHERE active_ingredient = 'faktör 8' AND atc_code = '0';

-- 5. Görüntüleme ve Diğerleri
UPDATE global_medications SET atc_code = 'V08CA01' WHERE active_ingredient IN ('gadopentetic acid', 'gadopentat dimeglumin') AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N06DX02' WHERE active_ingredient = 'idebenon' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'G01AX14' WHERE active_ingredient = 'lactic acid producing organisms' AND atc_code = '0';

-- 6. Daha önce konuştuğumuz Hepatit B Aşısı (8 tane temizler)
UPDATE global_medications SET atc_code = 'J07BC01' WHERE active_ingredient = 'saflaştirilmiş hepatit b yüzey antijeni' AND atc_code = '0';

COMMIT;




BEGIN;

-- 1. Tüm Demir (Ferrum vb.) Takviyeleri
-- İçinde 'demir' ve 'hidroksit' veya 'süksinilat' geçen her şeyi tek koda topluyoruz.
UPDATE global_medications SET atc_code = 'B03AB05' 
WHERE (active_ingredient ILIKE '%demir%hidroksit%' OR active_ingredient ILIKE '%demir%süksin%') 
AND atc_code = '0';

-- 2. Kalsiyum + Vitamin D Kombinasyonları
-- Listende çok fazla 'kalsiyum karbonat', 'vitamin d3' varyasyonu vardı.
UPDATE global_medications SET atc_code = 'A12AX' 
WHERE active_ingredient ILIKE '%kalsiyum%' AND active_ingredient ILIKE '%vitamin d3%' 
AND atc_code = '0';

-- 3. İnsülin Lispro ve Protamin Karışımları
-- %25, %50 gibi tüm o yüzdeli karmaşık satırları tek seferde yakalar.
UPDATE global_medications SET atc_code = 'A10AD04' 
WHERE active_ingredient ILIKE '%insülin lispro%' AND active_ingredient ILIKE '%protamin%' 
AND atc_code = '0';

-- 4. Amino Asit ve Karbonhidratlı Serumlar
-- 'aminoasit', 'glukoz', 'elektrolit' gibi kelime öbeklerini içeren serumlar.
UPDATE global_medications SET atc_code = 'B05BA10' 
WHERE active_ingredient ILIKE '%aminoasit%glukoz%' 
AND atc_code = '0';

-- 5. Antibiyotik Karışımları (Ampisilin + Sulbaktam varyasyonları)
-- 'ampisilin' ve 'sulbaktam' içeren, miligramı yazan tüm satırları temizler.
UPDATE global_medications SET atc_code = 'J01CR01' 
WHERE active_ingredient ILIKE '%ampisilin%' AND active_ingredient ILIKE '%sulbaktam%' 
AND atc_code = '0';

-- 6. Göz Damlaları (Dorzolamid + Timolol kombinasyonu)
UPDATE global_medications SET atc_code = 'S01ED51' 
WHERE active_ingredient ILIKE '%dorzalamid%' AND active_ingredient ILIKE '%timolol%' 
AND atc_code = '0';

COMMIT;

BEGIN;

-- 1. Asetilsalisilik Asit (Aspirin varyasyonları - ve kafein/askorbik asitli olanlar)
UPDATE global_medications SET atc_code = 'N02BA51' 
WHERE active_ingredient ILIKE '%asetil%salisilik%' AND (active_ingredient ILIKE '%kafein%' OR active_ingredient ILIKE '%askorbik%')
AND atc_code = '0';

-- 2. Benzidamin + Klorheksidin (Boğaz spreyleri - yazım hatalı olanlar dahil)
UPDATE global_medications SET atc_code = 'A01AD11' 
WHERE active_ingredient ILIKE '%benzidamin%' AND active_ingredient ILIKE '%klorheksidin%'
AND atc_code = '0';

-- 3. Formoterol + Budesonid (Fostair vb. - farklı bölü işareti olanlar)
UPDATE global_medications SET atc_code = 'R03AK07' 
WHERE active_ingredient ILIKE '%formoterol%' AND active_ingredient ILIKE '%budesonid%'
AND atc_code = '0';

-- 4. Demir ve Folik Asit Kombinasyonları (Gynoferon vb.)
UPDATE global_medications SET atc_code = 'B03AD03' 
WHERE active_ingredient ILIKE '%demir%' AND active_ingredient ILIKE '%folik%'
AND atc_code = '0';

-- 5. L-İzolösin (Amino asit solüsyonlarının o çok uzun isimleri)
UPDATE global_medications SET atc_code = 'B05BA01' 
WHERE active_ingredient ILIKE '%l-izolösin%' 
AND atc_code = '0';

-- 6. Betametazon varyasyonları (Dipropionat/Fosfat karışımları - Celestone vb.)
UPDATE global_medications SET atc_code = 'H02AB01' 
WHERE active_ingredient ILIKE '%betametazon%' 
AND atc_code = '0';

-- 7. Difenhidramin Kombinasyonları (Öksürük şurupları)
UPDATE global_medications SET atc_code = 'R06AA52' 
WHERE active_ingredient ILIKE '%difenhidramin%' 
AND atc_code = '0';

COMMIT;

BEGIN;

-- 1. Karmaşık Serumlar (Sodyum, Potasyum, Laktat, Magnezyum kombinasyonları)
-- Bu sorgu, o 3-4 satır süren devasa içerikleri tek seferde yakalar.
UPDATE global_medications SET atc_code = 'B05BB01' 
WHERE active_ingredient ILIKE '%sodyum klorür%' AND active_ingredient ILIKE '%potasyum klorür%' AND active_ingredient ILIKE '%magnezyum%'
AND atc_code = '0';

-- 2. İleri Seviye Astım/KOAH (İpratropium ve Salbutamol kombinasyonları - Combivent vb.)
UPDATE global_medications SET atc_code = 'R03AL02' 
WHERE active_ingredient ILIKE '%ipratropium%' AND active_ingredient ILIKE '%salbutamol%'
AND atc_code = '0';

-- 3. Cilt Enfeksiyonları (Fusidik Asit ve Kombinasyonları - Fucidin, Fucicort vb.)
UPDATE global_medications SET atc_code = 'D06AX01' 
WHERE active_ingredient ILIKE '%fusidik asit%' OR active_ingredient ILIKE '%fucid%'
AND atc_code = '0';

-- 4. Mantar ve Kortizon Kombinasyonları (Travocort vb.)
UPDATE global_medications SET atc_code = 'D01AC20' 
WHERE active_ingredient ILIKE '%izokonazol%' AND active_ingredient ILIKE '%diflukortolon%'
AND atc_code = '0';

-- 5. Anti-D İmmünglobulin (Rhogam vb. - Kan uyuşmazlığı iğnesi)
UPDATE global_medications SET atc_code = 'J06BB01' 
WHERE active_ingredient ILIKE '%anti-d%' 
AND atc_code = '0';

-- 6. Mide Asidi ve Gaz Kombinasyonları (Talcit, Gaviscon varyasyonları)
UPDATE global_medications SET atc_code = 'A02AD01' 
WHERE active_ingredient ILIKE '%sodyum aljinat%' AND active_ingredient ILIKE '%kalsiyum karbonat%'
AND atc_code = '0';

COMMIT;


BEGIN;

-- 1. B Grubu Vitaminleri (B1, B6, B12 ve Kompleksler)
-- Listende çok fazla 'b vitaminleri', 'b kompleksi' varyasyonu var.
UPDATE global_medications SET atc_code = 'A11EA' 
WHERE (active_ingredient ILIKE '%b vitamin%' OR active_ingredient ILIKE '%vitamin b%') 
AND atc_code = '0';

-- 2. Sefalosporin Antibiyotikler (Sef- ile başlayan neredeyse her şey)
UPDATE global_medications SET atc_code = 'J01DB04' 
WHERE active_ingredient ILIKE 'sefazolin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01DD04' 
WHERE active_ingredient ILIKE 'seftriakson%' AND atc_code = '0';

-- 3. Lidokain ve Prilokain (Lokal anestezi ve kremler - Emla vb.)
UPDATE global_medications SET atc_code = 'N01BB02' 
WHERE active_ingredient ILIKE '%lidokain%' AND atc_code = '0';

-- 4. Göz/Burun Alerji ve Kortizonları (Mometazon, Flutikazon vb.)
UPDATE global_medications SET atc_code = 'R01AD09' 
WHERE active_ingredient ILIKE '%mometazon%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R01AD08' 
WHERE active_ingredient ILIKE '%flutikazon%' AND atc_code = '0';

-- 5. Mide Koruyucu Kombinasyonları (Prazol + Domperidon varyasyonları)
-- Bu grup çok fazlaydı, ILIKE ile aradaki tüm karakterleri eziyoruz.
UPDATE global_medications SET atc_code = 'A02BC53' 
WHERE active_ingredient ILIKE '%lansoprazol%' AND active_ingredient ILIKE '%domperidon%'
AND atc_code = '0';

-- 6. Alendronat (Kemik Erimesi + Vitamin D varyasyonları)
UPDATE global_medications SET atc_code = 'M05BB03' 
WHERE active_ingredient ILIKE '%alendron%' AND active_ingredient ILIKE '%vitamin d%'
AND atc_code = '0';

-- 7. Yaygın Şuruplar (İbuprofen + Psödoefedrin + Klorfeniramin)
UPDATE global_medications SET atc_code = 'R05X' 
WHERE active_ingredient ILIKE '%ibuprofen%' AND active_ingredient ILIKE '%psödoefedrin%'
AND atc_code = '0';

COMMIT;

BEGIN;

-- 1. İnsan İmmünglobülinleri (Listende çok varyasyonu vardı: normal, insan vb.)
UPDATE global_medications SET atc_code = 'J06BA02' 
WHERE active_ingredient ILIKE '%insan%immünglobulin%' OR active_ingredient ILIKE '%insan%immunoglobulin%'
AND atc_code = '0';

-- 2. Kan Pıhtılaşma Faktörleri (Faktör 8, von Willebrand vb.)
UPDATE global_medications SET atc_code = 'B02BD02' 
WHERE active_ingredient ILIKE '%faktör%viii%' OR active_ingredient ILIKE '%faktör 8%'
AND atc_code = '0';

-- 3. Tansiyon Üçlü Kombinasyonlar (Irbesartan + Amlodipin + HCTZ)
-- Bunlar listende 3-4 kelimelik uzun satırlar halindeydi.
UPDATE global_medications SET atc_code = 'C09DX01' 
WHERE active_ingredient ILIKE '%irbesartan%' AND active_ingredient ILIKE '%amlodipin%' AND active_ingredient ILIKE '%hidroklorotiyazid%'
AND atc_code = '0';

-- 4. Olmesartan Kombinasyonları (Tansiyon - Olmetec Plus vb.)
UPDATE global_medications SET atc_code = 'C09DA08' 
WHERE active_ingredient ILIKE '%olmesartan%' AND active_ingredient ILIKE '%hidroklorotiyazid%'
AND atc_code = '0';

-- 5. Levodopa + Karbidopa (Parkinson - Farklı yazımlar)
UPDATE global_medications SET atc_code = 'N04BA02' 
WHERE active_ingredient ILIKE '%levodopa%' AND active_ingredient ILIKE '%karbidopa%'
AND atc_code = '0';

-- 6. Feniramin (Alerji - Avil vb.)
UPDATE global_medications SET atc_code = 'R06AB05' 
WHERE active_ingredient ILIKE '%feniramin%maleat%' 
AND atc_code = '0';

-- 7. Povidon İyot (Batikon vb. - Tüm yazımlar)
UPDATE global_medications SET atc_code = 'D08AG02' 
WHERE active_ingredient ILIKE '%povidon%iyot%' OR active_ingredient ILIKE '%povidone%'
AND atc_code = '0';

COMMIT;

BEGIN;

-- 1. Çoklu Mide Asidi Çözeltileri (Gaviscon Double Action vb.)
-- Sodyum aljinat, kalsiyum karbonat ve magnezyum karbonat içeren o uzun satırlar.
UPDATE global_medications SET atc_code = 'A02AD01' 
WHERE active_ingredient ILIKE '%sodyum aljinat%' AND active_ingredient ILIKE '%magnezyum%'
AND atc_code = '0';

-- 2. Göz Tansiyonu Kombinasyonları (Latanoprost + Timolol)
UPDATE global_medications SET atc_code = 'S01ED51' 
WHERE active_ingredient ILIKE '%latanoprost%' AND active_ingredient ILIKE '%timolol%'
AND atc_code = '0';

-- 3. Akne ve Cilt Bakım (Adapalen, Benzoyl Peroxide vb.)
UPDATE global_medications SET atc_code = 'D10AD53' 
WHERE active_ingredient ILIKE '%adapalen%' 
AND atc_code = '0';

-- 4. Geniş Spektrumlu Soğuk Algınlığı (Parasetamol + Klorfeniramin + Fenilefrin)
-- A-ferin, Tylol-Hot gibi çok yaygın ilaçların tüm yazımları.
UPDATE global_medications SET atc_code = 'R05X' 
WHERE active_ingredient ILIKE '%parasetamol%' AND active_ingredient ILIKE '%fenilefrin%'
AND atc_code = '0';

-- 5. Kortizonlu Kremler (Betametazon + Gentamisin/Kliokinol - Belogent vb.)
UPDATE global_medications SET atc_code = 'D07CC01' 
WHERE active_ingredient ILIKE '%betametazon%' AND active_ingredient ILIKE '%gentamisin%'
AND atc_code = '0';

-- 6. Demir + C Vitamini Kombinasyonları
UPDATE global_medications SET atc_code = 'B03AA07' 
WHERE active_ingredient ILIKE '%demir%' AND active_ingredient ILIKE '%askorbik%'
AND atc_code = '0';

-- 7. Antipsikotikler (Aripiprazol varyasyonları)
UPDATE global_medications SET atc_code = 'N05AX12' 
WHERE active_ingredient ILIKE '%aripiprazol%' 
AND atc_code = '0';

COMMIT;


BEGIN;

-- 1. Kritik Hastane ve Uzmanlık İlaçları
UPDATE global_medications SET atc_code = 'A10AE04' WHERE active_ingredient = 'insülin glarjin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N03AX14' WHERE active_ingredient = 'levatirasetam' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B01AC11' WHERE active_ingredient = 'iloprost' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M03AC09' WHERE active_ingredient = 'roküronyum bromür' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'V08CA09' WHERE active_ingredient = 'gadobutrol' AND atc_code = '0';

-- 2. Alerji ve Solunum (Feksofenadin'in hem HCl hem hcl versiyonu var, ikisini de yakalayalım)
UPDATE global_medications SET atc_code = 'R06AX26' WHERE active_ingredient ILIKE 'feksofenadin hcl%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R03DA11' WHERE active_ingredient = 'doksofilin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R03AL09' WHERE active_ingredient = 'umeklidinyum bromür' AND atc_code = '0';

-- 3. Mide ve Sindirim (Yazım hatalarını düzelterek yakalıyoruz)
UPDATE global_medications SET atc_code = 'A02AD01' WHERE active_ingredient LIKE 'magnezyum karbonat ve magnezyum oksikt%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A03FA01' WHERE active_ingredient = 'metoclopramide' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A09AA02' WHERE active_ingredient = 'pankreatin spesial' AND atc_code = '0';

-- 4. Tansiyon ve Kalp (Kaptopril vb.)
UPDATE global_medications SET atc_code = 'C09AA01' WHERE active_ingredient = 'kaptopril' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C02KX01' WHERE active_ingredient = 'bosentan monohidrat' AND atc_code = '0';

-- 5. Enfeksiyon ve Takviye
UPDATE global_medications SET atc_code = 'J05AF11' WHERE active_ingredient = 'tenofovir disoproksil fumarat' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01GB01' WHERE active_ingredient = 'kanamisin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'D03AX03' WHERE active_ingredient = 'dekspantenol' AND atc_code = '0';

-- 6. Kemik Erimesi ve Diğerleri
UPDATE global_medications SET atc_code = 'M05BX03' WHERE active_ingredient = 'stronsiyum ranelat' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B03XA01' WHERE active_ingredient = 'erythropoietin alfa' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N05AL01' WHERE active_ingredient = 'sulpride' AND atc_code = '0';

COMMIT;

BEGIN;

-- 1. Tansiyon ve Kalp (Kombinasyonlar ve Tekli İlaçlar)
UPDATE global_medications SET atc_code = 'C09DB08' WHERE active_ingredient ILIKE '%olmesartan%amlodipin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C09DA04' WHERE active_ingredient ILIKE '%irbesartan%diuretics%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C05AA08' WHERE active_ingredient = 'naftazon' AND atc_code = '0';

-- 2. Nöroloji ve Psikiyatri (Epilepsi, Parkinson, Migren)
UPDATE global_medications SET atc_code = 'N03AX12' WHERE active_ingredient = 'oxcarbamazepine' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N04BB01' WHERE active_ingredient = 'biperiden hcl' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N02CC01' WHERE active_ingredient = 'sumatriptan' AND atc_code = '0';

-- 3. Solunum ve Alerji
UPDATE global_medications SET atc_code = 'R03AL06' WHERE active_ingredient ILIKE '%tiotropium%siklesonid%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A03AB06' WHERE active_ingredient = 'otilonyum bromür' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R06AX27' WHERE active_ingredient = 'desloratadine' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R01AC03' WHERE active_ingredient = 'efedrin hcl' AND atc_code = '0';

-- 4. Kemik, Onkoloji ve Kan
UPDATE global_medications SET atc_code = 'M05BA08' WHERE active_ingredient = 'zoledronik asit monohidrat' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B03AB05' WHERE active_ingredient = 'demir (ii) glisin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B05AA06' WHERE active_ingredient = 'gelatin agents' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C03XA01' WHERE active_ingredient = 'tolvaptan' AND atc_code = '0';

-- 5. Enfeksiyon, Aşı ve Cilt
-- Beşli karma aşı (Difteri, Tetanoz vb.) için genel kod:
UPDATE global_medications SET atc_code = 'J07CA02' WHERE active_ingredient ILIKE '%difteri%tetanoz%pertussis%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'S01AA01' WHERE active_ingredient = 'kloramfenikol l' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'D08AJ08' WHERE active_ingredient = 'hidrokinon' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'P03AC04' WHERE active_ingredient = 'permetrin' AND atc_code = '0';

-- 6. Diğer (Anestezi ve Göz)
UPDATE global_medications SET atc_code = 'N01AB06' WHERE active_ingredient = 'isoflurane' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'S01JA01' WHERE active_ingredient = 'fluoresein sodyum' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A11HA03' WHERE active_ingredient = 'tocopherol (vit e)' AND atc_code = '0';

COMMIT;

BEGIN;

-- 1. Psikiyatri ve Nöroloji (Antidepresanlar ve Parkinson)
UPDATE global_medications SET atc_code = 'N06AX16' WHERE active_ingredient = 'venlafaksin hcl' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N06AX21' WHERE active_ingredient ILIKE 'duloksetin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N04BD02' WHERE active_ingredient ILIKE 'rasajilin%' AND atc_code = '0';

-- 2. Solunum ve Öksürük (Hayati önemde)
UPDATE global_medications SET atc_code = 'R05DB27' WHERE active_ingredient ILIKE 'levodropropizine%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R03DA01' WHERE active_ingredient = 'dihidroksipropil teofilin' AND atc_code = '0';

-- 3. Antibiyotik ve Antifungal (Enfeksiyon grubu)
UPDATE global_medications SET atc_code = 'J01FF02' WHERE active_ingredient = 'linkomisin hidroklorür' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'D01AC03' WHERE active_ingredient = 'ketokanazol' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'D01A' WHERE active_ingredient = 'antimycotique' AND atc_code = '0';

-- 4. Kan ve Kalp Damar
UPDATE global_medications SET atc_code = 'B01AB12' WHERE active_ingredient = 'bemiparin sodyum' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'B01AC07' WHERE active_ingredient = 'dipiridamol' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C01EB18' WHERE active_ingredient = 'ranolazin' AND atc_code = '0';

-- 5. Kas Gevşetici ve Ağrı Kombinasyonları (Çok yaygın)
UPDATE global_medications SET atc_code = 'M03BX55' WHERE active_ingredient ILIKE 'flurbiprofen / tiyokolşikosid%' AND atc_code = '0';

-- 6. Kemik Erimesi ve Hormon
UPDATE global_medications SET atc_code = 'M05BA07' WHERE active_ingredient = 'risedronat sodyum' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'G03GA04' WHERE active_ingredient = 'urofollitropin' AND atc_code = '0';

-- 7. Cilt ve Hijyen (Setrimid vb.)
UPDATE global_medications SET atc_code = 'D08AC' WHERE active_ingredient ILIKE 'setrimid%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'D07AA02' WHERE active_ingredient = 'hidrokortizon asetat' AND atc_code = '0';

-- 8. Diğer İnatçı Satırlar (Serum ve Vitamin)
UPDATE global_medications SET atc_code = 'A06AD17' WHERE active_ingredient ILIKE 'dibazik sodyum fosfat%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A11HA03' WHERE active_ingredient = 'vitamin e' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R01AA07' WHERE active_ingredient = 'fenilefrin hcl' AND atc_code = '0';

COMMIT;


BEGIN;

-- 1. Psikiyatri ve Nöroloji (Epilepsi ve Antidepresan)
UPDATE global_medications SET atc_code = 'N03AF01' WHERE active_ingredient = 'carbamazepine' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N06AA09' WHERE active_ingredient = 'amitriptilin hcl' AND atc_code = '0';

-- 2. Grip, Soğuk Algınlığı ve Aşılar (Çok kritik)
UPDATE global_medications SET atc_code = 'J05AH02' WHERE active_ingredient = 'oseltamivir fosfat' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J07BB02' WHERE active_ingredient ILIKE '%influenza%antijen%' OR active_ingredient ILIKE '%influenza%virus%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'N02CC05' WHERE active_ingredient = 'frovatriptan' AND atc_code = '0';

-- 3. Solunum ve Alerji
UPDATE global_medications SET atc_code = 'R03BA08' WHERE active_ingredient = 'siklesonid' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R03AL05' WHERE active_ingredient ILIKE '%tiotropium%formoterol%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'R06AD01' WHERE active_ingredient = 'astemizol' AND atc_code = '0';

-- 4. Sindirim, Mide ve Boşaltım
UPDATE global_medications SET atc_code = 'A06AB02' WHERE active_ingredient = 'bisakodil' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A04AD' WHERE active_ingredient ILIKE '%trimetobenzamid%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A02AD' WHERE active_ingredient ILIKE '%dihidroksialuminyum%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'A09AA02' WHERE active_ingredient = 'pankreatin' AND atc_code = '0';

-- 5. Antibiyotik ve Enfeksiyon
UPDATE global_medications SET atc_code = 'J01FA02' WHERE active_ingredient = 'spiramisin' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'J01DI01' WHERE active_ingredient = 'sefepim hcl' AND atc_code = '0';

-- 6. Kalp, Tansiyon ve Damar
UPDATE global_medications SET atc_code = 'C02CA04' WHERE active_ingredient = 'indapamide' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'C01CA07' WHERE active_ingredient = 'dobutamin hidroklorür' AND atc_code = '0';

-- 7. Takviyeler, Kemik ve Diğer
UPDATE global_medications SET atc_code = 'A11HA03' WHERE active_ingredient = 'vitamin-E acetate' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'M05BA06' WHERE active_ingredient = 'ibandronikasit sodyum monohidrat' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'P03AC54' WHERE active_ingredient ILIKE '%piretrin%' AND atc_code = '0';
UPDATE global_medications SET atc_code = 'D11' WHERE active_ingredient = 'triticum vulgare' AND atc_code = '0';

COMMIT;

COMMIT;