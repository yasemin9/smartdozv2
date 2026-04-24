from services.summarization_service import summarize_medication

result = summarize_medication(
    product_name="ASPİRİN 100 MG TABLET",
    description="""
    ASPİRİN 100 MG TABLET

    KULLANMA TALİMATI

    1. ASPİRİN NEDİR VE NE İÇİN KULLANILIR?

    Aspirin, asetilsalisilik asit içeren bir ağrı kesici, ateş düşürücü ve enflamasyon giderici ilaçtır.
    
    Kullanım Alanları:
    - Hafif ila orta şiddette ağrılar (baş ağrısı, diş ağrısı, kas ağrısı)
    - Ateş
    - Trombotik olayların önlenmesi
    """,
    active_ingredient="Asetilsalisilik asit",
    atc_code="N02BA01",
)

print("=" * 60)
print(f"Ürün: {result.product_name}")
print(f"Yöntem: {result.summary_method}")
print(f"\n🌟 Temel Faydası:")
for item in result.temel_faydasi:
    print(f"  • {item}")
print(f"\n🥄 Kullanım Şekli:")
for item in result.kullanim_sekli:
    print(f"  • {item}")
print(f"\n⚠️ Dikkat Edilecekler:")
for item in result.dikkat_edilecekler:
    print(f"  • {item}")
print(f"\n📋 Sorumluluk Reddi:")
print(f"  {result.disclaimer}")
print("=" * 60)