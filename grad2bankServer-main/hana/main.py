from fastapi import FastAPI, Depends, HTTPException
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session
from decimal import Decimal
import json
import models
import database


app = FastAPI()


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


def parse_benefits(raw_benefits):
    if raw_benefits is None:
        return {}

    if isinstance(raw_benefits, dict):
        return raw_benefits

    if isinstance(raw_benefits, str):
        try:
            return json.loads(raw_benefits)
        except json.JSONDecodeError:
            return {"raw": raw_benefits}

    return raw_benefits


def to_float(value):
    if value is None:
        return None
    if isinstance(value, Decimal):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def get_attr(obj, *field_names, default=None):
    for field_name in field_names:
        if hasattr(obj, field_name):
            value = getattr(obj, field_name)
            if value is not None:
                return value
    return default


def normalize_card_type(card_type: str | None):
    if not card_type:
        return None

    value = card_type.strip().lower()
    if value in ["credit", "신용"]:
        return "CREDIT"
    if value in ["check", "체크", "debit"]:
        return "CHECK"
    return card_type.upper()


def serialize_card(card: models.Card):
    return {
        "card_id": str(card.card_id),
        "card_name": card.card_name,
        "card_type": normalize_card_type(card.card_type),
        "limit_amount": to_float(card.limit_amount),
        "benefits": parse_benefits(card.benefits),
        "is_active": card.is_active,
    }


def serialize_user_card(card: models.Users_Cards):
    return {
        "account_id": str(card.account_id) if card.account_id else None,
        "card_number": card.card_number,
        "card_name": card.card_name,
        "card_type": normalize_card_type(card.card_type),
        "expiry_date": str(card.expiry_date) if card.expiry_date else None,
        "limit_amount": to_float(card.limit_amount),
        "benefits": parse_benefits(card.benefits),
        "is_active": card.is_active,
    }


def serialize_account(account: models.Account):
    return {
        "account_id": str(account.account_id),
        "user_id": str(account.user_id) if account.user_id else None,
        "account_number": account.account_number,
        "account_type": account.account_type,
        "balance": to_float(account.balance) if account.balance is not None else 0.0,
        "cards": [serialize_user_card(card) for card in account.cards] if account.cards else [],
    }


def serialize_transaction(tx: models.Transaction):
    return {
        "transaction_id": str(tx.transaction_id),
        "from_account": tx.from_account,
        "to_account": tx.to_account,
        "amount": to_float(tx.amount) if tx.amount is not None else 0.0,
        "transaction_type": tx.transaction_type,
        "category": tx.category,
        "created_at": tx.created_at.isoformat() if tx.created_at else None,
        "account_id": str(tx.account_id) if tx.account_id else None,
        "channel": get_attr(tx, "channel", "transaction_channel"),
    }


def serialize_card_benefit(benefit: models.CardBenefit):
    return {
        "card_benefit_id": str(benefit.card_benefit_id),
        "card_id": str(benefit.card_id),
        "category_code": benefit.category_code,
        "merchant_name": benefit.merchant_name,
        "benefit_type": benefit.benefit_type,
        "benefit_value": to_float(benefit.benefit_value),
        "benefit_unit": benefit.benefit_unit,
        "description": benefit.description,
        "is_active": benefit.is_active,

        # 확장 필드
        "previous_month_spend_min": to_float(
            get_attr(benefit, "previous_month_spend_min", "prev_month_spend_min")
        ),
        "previous_month_spend_max": to_float(
            get_attr(benefit, "previous_month_spend_max", "prev_month_spend_max")
        ),
        "monthly_benefit_limit": to_float(
            get_attr(benefit, "monthly_benefit_limit", "monthly_limit", "benefit_monthly_limit")
        ),
        "max_benefit_count_per_month": get_attr(
            benefit, "max_benefit_count_per_month", "monthly_max_count", "benefit_max_count_per_month"
        ),
        "per_transaction_min_amount": to_float(
            get_attr(benefit, "per_transaction_min_amount", "min_transaction_amount")
        ),
        "per_transaction_max_amount": to_float(
            get_attr(benefit, "per_transaction_max_amount", "max_transaction_amount")
        ),
        "eligible_channels": get_attr(
            benefit, "eligible_channels", "channel_condition", "available_channels"
        ),
    }


def serialize_promotion(promotion: models.Promotion):
    return {
        "promotion_id": str(promotion.promotion_id),
        "title": promotion.title,
        "content": promotion.content,
        "start_date": promotion.start_date.isoformat() if promotion.start_date else None,
        "end_date": promotion.end_date.isoformat() if promotion.end_date else None,
        "is_active": promotion.is_active,
        "category": promotion.category,
        "benefit_type": promotion.benefit_type,
        "benefit_value": to_float(promotion.benefit_value) if promotion.benefit_value is not None else 0.0,
        "target_cards": promotion.target_cards,
        "merchant_name": promotion.merchant_name,
        "category_code": promotion.category_code,

        # 확장 필드
        "promotion_min_amount": to_float(
            get_attr(promotion, "promotion_min_amount", "min_amount")
        ),
        "promotion_max_benefit_amount": to_float(
            get_attr(promotion, "promotion_max_benefit_amount", "max_benefit_amount")
        ),
        "promotion_max_count": get_attr(
            promotion, "promotion_max_count", "max_count"
        ),
        "promotion_channel": get_attr(
            promotion, "promotion_channel", "channel_condition", "available_channel"
        ),
        "stackable_with_base_benefit": get_attr(
            promotion, "stackable_with_base_benefit", "allow_stack_with_base_benefit", default=None
        ),
    }


def is_all_target(target_cards: str | None) -> bool:
    if not target_cards:
        return False
    return target_cards.strip().lower() == "all"


def parse_target_cards(target_cards: str | None):
    if not target_cards:
        return []

    return [
        item.strip()
        for item in target_cards.split(",")
        if item and item.strip()
    ]


def find_promotions_for_card(card: models.Card, promotions: list[models.Promotion]):
    matched = []
    card_name = (card.card_name or "").strip()

    for promo in promotions:
        if not promo.is_active:
            continue

        if is_all_target(promo.target_cards):
            matched.append(promo)
            continue

        target_card_names = parse_target_cards(promo.target_cards)
        if card_name and card_name in target_card_names:
            matched.append(promo)

    return matched


def build_card_catalog_item(
    card: models.Card,
    benefits: list[models.CardBenefit],
    promotions: list[models.Promotion]
):
    return {
        "bank_code": "hana",
        "card_id": str(card.card_id),
        "card_name": card.card_name,
        "card_type": normalize_card_type(card.card_type),
        "limit_amount": to_float(card.limit_amount),
        "benefits": parse_benefits(card.benefits),
        "is_active": card.is_active,
        "card_benefits": [serialize_card_benefit(b) for b in benefits],
        "promotions": [serialize_promotion(p) for p in promotions],
    }


@app.get("/bank/marketing")
def get_bank_marketing_info(db: Session = Depends(get_db)):
    cards = db.query(models.Card).filter(models.Card.is_active == True).all()
    promotions = db.query(models.Promotion).filter(models.Promotion.is_active == True).all()

    result = {
        "bank_name": "hana",
        "available_cards": [serialize_card(card) for card in cards],
        "active_promotions": [serialize_promotion(promo) for promo in promotions]
    }
    return jsonable_encoder(result)


@app.get("/user/assets/{email}")
def get_user_integrated_assets(email: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="해당 이메일의 사용자를 찾을 수 없습니다.")

    accounts = db.query(models.Account).filter(models.Account.user_id == user.user_id).all()
    all_cards = []
    all_transactions = []

    for acc in accounts:
        all_cards.extend(acc.cards)

    if accounts:
        account_ids = [acc.account_id for acc in accounts]
        all_transactions = db.query(models.Transaction).filter(
            models.Transaction.account_id.in_(account_ids)
        ).order_by(models.Transaction.created_at.desc()).limit(30).all()

    result = {
        "bank": "hana",
        "user_name": user.username,
        "accounts": [serialize_account(acc) for acc in accounts],
        "my_cards": [serialize_user_card(card) for card in all_cards],
        "transactions": [serialize_transaction(tx) for tx in all_transactions]
    }
    return jsonable_encoder(result)


@app.get("/api/v1/catalog/cards")
def get_card_catalog(db: Session = Depends(get_db)):
    cards = db.query(models.Card).filter(models.Card.is_active == True).all()
    card_benefits = db.query(models.CardBenefit).filter(models.CardBenefit.is_active == True).all()
    promotions = db.query(models.Promotion).filter(models.Promotion.is_active == True).all()

    benefits_map = {}
    for benefit in card_benefits:
        card_id = str(benefit.card_id)
        if card_id not in benefits_map:
            benefits_map[card_id] = []
        benefits_map[card_id].append(benefit)

    catalog = []
    for card in cards:
        card_id = str(card.card_id)
        matched_benefits = benefits_map.get(card_id, [])
        matched_promotions = find_promotions_for_card(card, promotions)

        catalog.append(build_card_catalog_item(card, matched_benefits, matched_promotions))

    result = {
        "bank_code": "hana",
        "cards": catalog,
        "count": len(catalog)
    }
    return jsonable_encoder(result)


@app.get("/api/v1/catalog/cards/{card_id}")
def get_card_catalog_detail(card_id: str, db: Session = Depends(get_db)):
    card = db.query(models.Card).filter(
        models.Card.card_id == card_id,
        models.Card.is_active == True
    ).first()

    if not card:
        raise HTTPException(status_code=404, detail="해당 카드 상품을 찾을 수 없습니다.")

    benefits = db.query(models.CardBenefit).filter(
        models.CardBenefit.card_id == card.card_id,
        models.CardBenefit.is_active == True
    ).all()

    promotions = db.query(models.Promotion).filter(models.Promotion.is_active == True).all()
    matched_promotions = find_promotions_for_card(card, promotions)

    result = build_card_catalog_item(card, benefits, matched_promotions)
    return jsonable_encoder(result)