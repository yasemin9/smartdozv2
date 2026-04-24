from fastapi import APIRouter, HTTPException, Depends, Query, UploadFile, File
from typing import Optional
from sqlalchemy.orm import Session
from datetime import datetime
import logging
import tempfile
import os

from database import get_db
from models import Prospectus, ProspectusAnalytics, ProspectusUserReading, User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/prospectus", tags=["prospectus"])

# ✅ ÖNCE İmport'ları kontrol et - eğer hata varsa try/except ile al
try:
    from core.security import get_current_user
except ImportError:
    logger.warning("⚠️ get_current_user core.security'den import edilemedi, users.py'den deneniyor")
    try:
        from routers.users import get_current_user
    except ImportError:
        logger.warning("⚠️ get_current_user hiçbir yerden import edilemedi - Optional yapılıyor")
        async def get_current_user(db: Session = Depends(get_db)):
            """Placeholder - geçici authentication"""
            return None

# ProspectusEngine ve SummarizationService
try:
    from services.prospectus_engine import ProspectusEngine
    from services.summarization_service import SummarizationService
    prospectus_engine = ProspectusEngine()
    summarization_service = SummarizationService()
except ImportError as e:
    logger.error(f"❌ Service import hatası: {e}")
    prospectus_engine = None
    summarization_service = None


@router.post("/import-csv", tags=["İçeri Aktarma"])
async def import_prospectus_from_csv(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """
    CSV dosyasından prospektüsleri içeri aktar.
    
    CSV Format:
    ```
    product_name,prospectus_link
    İlaç Adı,https://example.com/prospectus.pdf
    ```
    """
    
    if not prospectus_engine:
        raise HTTPException(status_code=500, detail="ProspectusEngine başlatılamadı")
    
    try:
        # Dosyayı temp olarak kaydet
        with tempfile.NamedTemporaryFile(delete=False, suffix=".csv", mode='wb') as temp_file:
            content = await file.read()
            temp_file.write(content)
            temp_path = temp_file.name
        
        # CSV'yi içeri aktar
        imported_count = await prospectus_engine.import_from_csv(temp_path, db)
        
        # Temp dosyayı sil
        os.unlink(temp_path)
        
        logger.info(f"✅ {imported_count} prospektüs başarıyla içeri aktarıldı")
        
        return {
            "status": "success",
            "message": f"{imported_count} prospektüs başarıyla içeri aktarıldı",
            "imported_count": imported_count
        }
    
    except Exception as e:
        logger.error(f"❌ CSV içeri aktarma hatası: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"İçeri aktarma hatası: {str(e)}")


@router.get("/list", tags=["Listeleme"])
async def get_prospectus_list(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=100),
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """
    Prospektüs listesini al.
    
    Parametreler:
    - skip: Atlanacak kayıt sayısı
    - limit: Gösterilecek kayıt sayısı
    - search: Aranacak terim
    """
    try:
        query = db.query(Prospectus)
        
        if search and len(search) > 2:
            query = query.filter(
                Prospectus.product_name.ilike(f"%{search}%")
            )
        
        total = query.count()
        prospectus_list = query.offset(skip).limit(limit).all()
        
        return {
            "total": total,
            "skip": skip,
            "limit": limit,
            "data": [
                {
                    "id": p.id,
                    "product_name": p.product_name,
                    "is_summarized": p.is_summarized,
                    "prospectus_link": p.prospectus_link,
                    "summary_created_at": p.last_updated.isoformat() if p.is_summarized else None
                }
                for p in prospectus_list
            ]
        }
    
    except Exception as e:
        logger.error(f"❌ Prospektüs listesi hatası: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{prospectus_id}/summary", tags=["Görüntüleme"])
async def get_prospectus_summary(
    prospectus_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """Prospektüsün AI tarafından oluşturulmuş özetini al."""
    
    if not prospectus_engine or not summarization_service:
        raise HTTPException(status_code=500, detail="Service başlatılamadı")
    
    try:
        prospectus = db.query(Prospectus).filter(
            Prospectus.id == prospectus_id
        ).first()
        
        if not prospectus:
            raise HTTPException(status_code=404, detail="Prospektüs bulunamadı")
        
        # Özet yoksa oluştur
        if not prospectus.is_summarized:
            # Tam metin yoksa indir
            if not prospectus.full_text:
                prospectus.full_text = await prospectus_engine.download_prospectus(
                    prospectus.prospectus_link
                )
                
                if not prospectus.full_text:
                    raise HTTPException(
                        status_code=500,
                        detail="Prospektüs indirilemedi"
                    )
            
            # AI özeti oluştur
            summary = await summarization_service.summarize_prospectus(
                prospectus.full_text,
                prospectus.product_name
            )
            
            prospectus.summary_text = summary
            prospectus.is_summarized = True
            prospectus.last_updated = datetime.utcnow()
            
            # Analytics kaydı oluştur (yoksa)
            analytics = db.query(ProspectusAnalytics).filter(
                ProspectusAnalytics.prospectus_id == prospectus_id
            ).first()
            
            if not analytics:
                analytics = ProspectusAnalytics(prospectus_id=prospectus_id)
                db.add(analytics)
            
            db.commit()
            logger.info(f"✅ Prospektüs {prospectus_id} özetlendi")
        
        # Okuma geçmişi kaydet (eğer user varsa)
        if current_user:
            _record_reading(db, current_user.id, prospectus_id, 'summary')
        
        return {
            "id": prospectus.id,
            "product_name": prospectus.product_name,
            "prospectus_link": prospectus.prospectus_link,
            "summary_text": prospectus.summary_text,
            "is_summarized": prospectus.is_summarized,
            "last_updated": prospectus.last_updated.isoformat()
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Özet alma hatası: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{prospectus_id}/full-text", tags=["Görüntüleme"])
async def get_prospectus_full_text(
    prospectus_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """Prospektüsün tam metnini al."""
    
    if not prospectus_engine:
        raise HTTPException(status_code=500, detail="ProspectusEngine başlatılamadı")
    
    try:
        prospectus = db.query(Prospectus).filter(
            Prospectus.id == prospectus_id
        ).first()
        
        if not prospectus:
            raise HTTPException(status_code=404, detail="Prospektüs bulunamadı")
        
        # Tam metin yoksa indir
        if not prospectus.full_text:
            prospectus.full_text = await prospectus_engine.download_prospectus(
                prospectus.prospectus_link
            )
            
            if not prospectus.full_text:
                raise HTTPException(
                    status_code=500,
                    detail="Prospektüs indirilemedi"
                )
            
            prospectus.last_updated = datetime.utcnow()
            db.commit()
            logger.info(f"✅ Prospektüs {prospectus_id} tam metni indirildi")
        
        # Okuma geçmişi kaydet (eğer user varsa)
        if current_user:
            _record_reading(db, current_user.id, prospectus_id, 'full_text')
        
        return {
            "id": prospectus.id,
            "product_name": prospectus.product_name,
            "full_text": prospectus.full_text
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Tam metin alma hatası: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/batch-summarize", tags=["İşleme"])
async def batch_summarize_prospectus(
    batch_size: int = Query(5, ge=1, le=20),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """Toplu olarak prospektüsleri özetle."""
    
    if not prospectus_engine or not summarization_service:
        raise HTTPException(status_code=500, detail="Service başlatılamadı")
    
    try:
        unsummarized = db.query(Prospectus).filter(
            Prospectus.is_summarized == False
        ).limit(batch_size).all()
        
        summarized_count = 0
        errors = []
        
        for prospectus in unsummarized:
            try:
                if not prospectus.full_text:
                    prospectus.full_text = await prospectus_engine.download_prospectus(
                        prospectus.prospectus_link
                    )
                    
                    if not prospectus.full_text:
                        errors.append(f"{prospectus.product_name}: İndirme başarısız")
                        continue
                
                summary = await summarization_service.summarize_prospectus(
                    prospectus.full_text,
                    prospectus.product_name
                )
                
                prospectus.summary_text = summary
                prospectus.is_summarized = True
                prospectus.last_updated = datetime.utcnow()
                
                analytics = db.query(ProspectusAnalytics).filter(
                    ProspectusAnalytics.prospectus_id == prospectus.id
                ).first()
                
                if not analytics:
                    analytics = ProspectusAnalytics(prospectus_id=prospectus.id)
                    db.add(analytics)
                
                summarized_count += 1
                logger.info(f"✅ {prospectus.product_name} özetlendi")
            
            except Exception as e:
                logger.warning(f"⚠️ Prospektüs {prospectus.id} özetleme hatası: {e}")
                errors.append(f"{prospectus.product_name}: {str(e)}")
                continue
        
        db.commit()
        
        return {
            "status": "success",
            "summarized_count": summarized_count,
            "total_processed": len(unsummarized),
            "errors": errors if errors else None
        }
    
    except Exception as e:
        logger.error(f"❌ Toplu özet oluşturma hatası: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/analytics/{prospectus_id}", tags=["Analitik"])
async def get_prospectus_analytics(
    prospectus_id: int,
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user)
):
    """Prospektüsün analitiklerini al."""
    try:
        analytics = db.query(ProspectusAnalytics).filter(
            ProspectusAnalytics.prospectus_id == prospectus_id
        ).first()
        
        if not analytics:
            raise HTTPException(status_code=404, detail="Analitik bulunamadı")
        
        return {
            "prospectus_id": analytics.prospectus_id,
            "view_count": analytics.view_count,
            "unique_viewers": analytics.unique_viewers,
            "last_viewed": analytics.last_viewed.isoformat() if analytics.last_viewed else None,
            "created_at": analytics.created_at.isoformat()
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Analitik alma hatası: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


def _record_reading(db: Session, user_id: int, prospectus_id: int, view_type: str):
    """Kullanıcı okuma geçmişini kaydet ve analitikleri güncelle."""
    try:
        reading = db.query(ProspectusUserReading).filter(
            ProspectusUserReading.user_id == user_id,
            ProspectusUserReading.prospectus_id == prospectus_id
        ).first()
        
        if reading:
            reading.view_type = view_type
            reading.read_at = datetime.utcnow()
        else:
            reading = ProspectusUserReading(
                user_id=user_id,
                prospectus_id=prospectus_id,
                view_type=view_type,
                read_at=datetime.utcnow()
            )
            db.add(reading)
        
        # Analytics güncelle
        analytics = db.query(ProspectusAnalytics).filter(
            ProspectusAnalytics.prospectus_id == prospectus_id
        ).first()
        
        if analytics:
            analytics.view_count += 1
            analytics.last_viewed = datetime.utcnow()
        
        db.commit()
    
    except Exception as e:
        logger.warning(f"⚠️ Okuma geçmişi kaydı hatası: {e}")
        db.rollback()