from database import SessionLocal
from models import Medication

db = SessionLocal()

# Aspirin 100 mg tablete açıklama ekle
medication = db.query(Medication).filter(
    Medication.product_name.like("%ASPIRIN%100%")
).first()

if medication:
    medication.description = """
    ASPİRİN 100 MG TABLET

    KULLANMA TALİMATI

    1. ASPİRİN NEDİR VE NE İÇİN KULLANILIR?

    Aspirin, asetilsalisilik asit içeren bir ağrı kesici, ateş düşürücü ve enflamasyon giderici ilaçtır. Ayrıca kan pıhtılaşmasını azaltıcı özellikleri bulunmaktadır.

    Kullanım Alanları:
    - Hafif ila orta şiddette ağrılar (baş ağrısı, diş ağrısı, kas ağrısı, menstrüel kramplar)
    - Ateş
    - Enflamasyonlu durumlarda
    - Trombotik olayların önlenmesi (özellikle kardiyovasküler hastalıklarda)
    - Miyokard infarktüsü ve inme riskinin azaltılması

    2. ASPİRİN KULLANMADAN ÖNCE DİKKAT EDİLMESİ GEREKENLER

    ASPİRİN'i KULLANMAYINIZ:
    - Asetilsalisilik asite karşı alerjiniz varsa
    - Astım, ürtiker veya alerjik rinit öyküsünüz varsa
    - Mide ülseri veya gastrointestinal kanama öyküsünüz varsa
    - Hamilelik son 3 ayında
    - Emzirme döneminde (gerekli olmadıkça)
    - Ciddi karaciğer veya böbrek hastalığınız varsa
    - Kan pıhtılaşma bozukluğunuz varsa
    - Warfarin veya benzeri kan sulandırıcıları kullanıyorsanız

    DİKKATLİ KULLANINIZ:
    - Mide duyarlılığı olan kişilerde
    - Yaşlı hastalar
    - Yüksek doz kullanacaksanız
    - Uzun süreli kullanımda
    - Metotreksat kullanıyorsanız

    3. ASPİRİN NASIL KULLANILIR?

    Doz Önerileri:
    - Ağrı ve ateş için: 500-1000 mg, her 4-6 saatte bir, günde maksimum 4000 mg
    - Kardiyovasküler koruma: 75-100 mg günde bir kez (uzun süreli)
    - Çocuklarda: Doktor önerisi ile (genellikle 3-12 yaş arası 125-250 mg)

    Kullanım Şekli:
    - Tablet ağızdan alınır
    - Yeterli su ile alınmalıdır
    - Yemekten sonra alınması tercih edilir (mide irritasyonunu azaltır)
    - Çiğnenmeden bütün olarak yutulmalıdır

    4. YABANCU ETKİLER VE UYARILAR

    Sık görülen yan etkiler:
    - Mide rahatsızlığı, bulantı
    - Baş ağrısı (paradoksal)
    - Kas ağrıları
    - İshal

    Nadir fakat ciddi yan etkiler:
    - Gastrointestinal kanama
    - Alerjik reaksiyonlar (anaflaksi)
    - Reynold sendromu (ateş, ensefalit)
    - Hiper ürisemi
    - Böbrek hastalığı

    Dikkat: Mide ağrısı, buzlu dışkı, kusma, kulak çınlaması veya işitme kaybı gibi belirtiler görürseniz derhal doktorunuza başvurunuz.

    5. DİĞER İLAÇLAR İLE ETKİLEŞİMLER

    Etkileşim riski olan ilaçlar:
    - Warfarin, heparin (kan sulandırıcılar)
    - Metotreksat (kanser ilaçları)
    - NSAİİ'ler (ibupuprofen, naproksen)
    - Kortikosteroidler
    - ACE inhibitörleri
    - Diüretikler
    - Lityum
    - Trombosit inhibitörleri (klopidogrel)

    6. SAKLANMASI

    - Oda sıcaklığında (15-25°C) saklanmalıdır
    - Nem ve ışıktan korunmalı
    - Çocukların erişemeyeceği yerde tutulmalı
    - Son kullanma tarihinden sonra kullanılmamalıdır

    7. İPUÇLARı

    - Günde 5000 tablet ise, her gün 100 mg alan bir kişi 50 gün süreyle kullanabilir
    - Kardiyovasküler koruma için uzun süreli (kronik) kullanım yapılabilir
    - Ağrı gidermek için ise kısa süreli (5-7 gün) kullanınız
    - İyileşme yoksa doktora başvurunuz
    """
    db.commit()
    print("✅ Aspirin 100 mg Tablet açıklaması başarıyla eklendi!")
    print(f"📦 5000 adet için yaklaşık 50 günlük arz bulunmaktadır (günde 100 mg = 1 tablet).")
else:
    print("❌ Aspirin 100 mg Tablet bulunamadı")
    print("💡 İpucu: Ürün adını kontrol ediniz: ASPIRIN, ASPIRIN 100, vb.")

db.close()
