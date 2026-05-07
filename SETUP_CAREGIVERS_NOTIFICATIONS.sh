#!/bin/bash
# SmartDoz - Migrasyon ve İlk Kurulum Rehberi

echo "🔧 SmartDoz - Modül 2 (Bakıcı & Bildirim Sistemi) Kurulumu"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Veritabanı bilgileri
DB_USER="smartdoz_user"
DB_NAME="smartdoz_db"
DB_HOST="localhost"

echo "📋 Adım 1: Migrasyon dosyasını PostgreSQL'de çalıştırma..."
echo "Komut: psql -U $DB_USER -d $DB_NAME -h $DB_HOST -f backend/migrations/004_add_caregivers_and_notifications.sql"
echo ""
echo "Çalıştırmak için aşağıdaki komutu terminal'de girin:"
echo ""
echo "psql -U $DB_USER -d $DB_NAME -h $DB_HOST -f backend/migrations/004_add_caregivers_and_notifications.sql"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📋 Adım 2: Backend bağımlılıklarını kontrol edin"
echo "Komut: cd backend && pip install -r requirements.txt"
echo ""

echo "📋 Adım 3: Backend sunucusunu başlatın"
echo "Komut: cd backend && uvicorn main:app --reload --host 0.0.0.0 --port 8000"
echo ""

echo "📋 Adım 4: API Test Endpoint'leri"
echo ""
echo "Swagger UI:  http://localhost:8000/docs"
echo "ReDoc:       http://localhost:8000/redoc"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Kurulum hazırdır!"
