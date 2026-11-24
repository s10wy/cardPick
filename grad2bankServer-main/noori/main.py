from fastapi import FastAPI, Depends, HTTPException
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session
from decimal import Decimal
import json
import models
import database


app = FastAPI()

BANK_CODE = "noori"
BANK_NAME = "noori"


def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_model(model_name: str):
    return getattr(models, model_name, None)


def query_all_if_model_exists(db: Session, model_name: str, active_field: str = "is_active"):
    model = get_model(model_name)
    if model is None:
        return []

    if hasattr(model, active_field):
        return db.query(model).filter(getattr(model, active_field) == True).all()

    return db.query(model).all()


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


def serialize_card(card):
    return {
        "card_id": str(get_attr(card, "card_id")),
        "card_name": get_attr(card, "card_name"),
        "card_type": normalize_card_type(get_attr(card, "card_type")),
        "limit_amount": to_float(get_attr(card, "limit_amount")),
        "benefits": parse_benefits(get_attr(card, "benefits")),
        "is_active": get_attr(card, "is_active", default=True),
    }


def serialize_user_card(card):
    return {
        "account_id": str(get_attr(card, "account_id")) if get_attr(card, "account_id") else None,
        "card_number": get_attr(card, "card_number"),
        "card_name": get_attr(card, "card_name"),
        "card_type": normalize_card_type(get_attr(card, "card_type")),
        "expiry_date": str(get_attr(card, "expiry_date")) if get_attr(card, "expiry_date") else None,
        "limit_amount": to_float(get_attr(card, "limit_amount")),
        "benefits": parse_benefits(get_attr(card, "benefits")),
        "is_active": get_attr(card, "is_active", default=True),
    }


def serialize_account(account):
    cards = get_attr(account, "cards", default=[]) or []
    return {
        "account_id": str(get_attr(account, "account_id")),
        "user_id": str(get_attr(account, "user_id")) if get_attr(account, "user_id") else None,
        "account_number": get_attr(account, "account_number"),
        "account_type": get_attr(account, "account_type"),
        "balance": to_float(get_attr(account, "balance")) if get_attr(account, "balance") is not None else 0.0,
        "cards": [serialize_user_card(card) for card in cards],
    }


def serialize_transaction(tx):
    return {
        "transaction_id": str(get_attr(tx, "transaction_id")),
        "from_account": get_attr(tx, "from_account"),
        "to_account": get_attr(tx, "to_account"),
        "amount": to_float(get_attr(tx, "amount")) if get_attr(tx, "amount") is not None else 0.0,
        "transaction_type": get_attr(tx, "transaction_type"),
        "category": get_attr(tx, "category"),
        "created_at": get_attr(tx, "created_at").isoformat() if get_attr(tx, "created_at") else None,
        "account_id": str(get_attr(tx, "account_id")) if get_attr(tx, "account_id") else None,
        "channel": get_attr(tx, "channel", "transaction_channel"),
        "category_code": get_attr(tx, "category_code"),
    }


def serialize_card_benefit(benefit):
    return {
        "card_benefit_id": str(get_attr(benefit, "card_benefit_id")) if get_attr(benefit, "card_benefit_id") else None,
        "card_id": str(get_attr(benefit, "card_id")) if get_attr(benefit, "card_id") else None,
        "category_code": get_attr(benefit, "category_code"),
        "merchant_name": get_attr(benefit, "merchant_name"),
        "benefit_type": get_attr(benefit, "benefit_type"),
        "benefit_value": to_float(get_attr(benefit, "benefit_value")),
        "benefit_unit": get_attr(benefit, "benefit_unit"),
        "description": get_attr(benefit, "description"),
        "is_active": get_attr(benefit, "is_active", default=True),
        "previous_month_spend_min": to_float(get_attr(benefit, "previous_month_spend_min", "prev_month_spend_min")),
        "previous_month_spend_max": to_float(get_attr(benefit, "previous_month_spend_max", "prev_month_spend_max")),
        "monthly_benefit_limit": to_float(get_attr(benefit, "monthly_benefit_limit", "monthly_limit", "benefit_monthly_limit")),
        "max_benefit_count_per_month": get_attr(benefit, "max_benefit_count_per_month", "monthly_max_count", "benefit_max_count_per_month"),
        "per_transaction_min_amount": to_float(get_attr(benefit, "per_transaction_min_amount", "min_transaction_amount")),
        "per_transaction_max_amount": to_float(get_attr(benefit, "per_transaction_max_amount", "max_transaction_amount")),
        "eligible_channels": get_attr(benefit, "eligible_channels", "channel_condition", "available_channels"),
    }


def serialize_promotion(promotion):
    return {
        "promotion_id": str(get_attr(promotion, "promotion_id")) if get_attr(promotion, "promotion_id") else None,
        "title": get_attr(promotion, "title"),
        "content": get_attr(promotion, "content"),
        "start_date": get_attr(promotion, "start_date").isoformat() if get_attr(promotion, "start_date") else None,
        "end_date": get_attr(promotion, "end_date").isoformat() if get_attr(promotion, "end_date") else None,
        "is_active": get_attr(promotion, "is_active", default=True),
        "category": get_attr(promotion, "category"),
        "benefit_type": get_attr(promotion, "benefit_type"),
        "benefit_value": to_float(get_attr(promotion, "benefit_value")) if get_attr(promotion, "benefit_value") is not None else 0.0,
        "target_cards": get_attr(promotion, "target_cards"),
        "merchant_name": get_attr(promotion, "merchant_name"),
        "category_code": get_attr(promotion, "category_code"),
        "promotion_min_amount": to_float(get_attr(promotion, "promotion_min_amount", "min_amount")),
        "promotion_max_benefit_amount": to_float(get_attr(promotion, "promotion_max_benefit_amount", "max_benefit_amount")),
        "promotion_max_count": get_attr(promotion, "promotion_max_count", "max_count"),
        "promotion_channel": get_attr(promotion, "promotion_channel", "channel_condition", "available_channel"),
        "stackable_with_base_benefit": get_attr(promotion, "stackable_with_base_benefit", "allow_stack_with_base_benefit", default=None),
    }


def is_all_target(target_cards: str | None) -> bool:
    if not target_cards:
        return False
    return str(target_cards).strip().lower() == "all"


def parse_target_cards(target_cards: str | None):
    if not target_cards:
        return []
    return [item.strip() for item in str(target_cards).split(",") if item and item.strip()]


def find_promotions_for_card(card, promotions):
    matched = []
    card_name = (get_attr(card, "card_name", default="") or "").strip()

    for promo in promotions:
        if not get_attr(promo, "is_active", default=True):
            continue

        target_cards = get_attr(promo, "target_cards")
        if is_all_target(target_cards):
            matched.append(promo)
            continue

        target_card_names = parse_target_cards(target_cards)
        if card_name and card_name in target_card_names:
            matched.append(promo)

    return matched


def build_card_catalog_item(card, benefits, promotions):
    return {
        "bank_code": BANK_CODE,
        "card_id": str(get_attr(card, "card_id")),
        "card_name": get_attr(card, "card_name"),
        "card_type": normalize_card_type(get_attr(card, "card_type")),
        "limit_amount": to_float(get_attr(card, "limit_amount")),
        "benefits": parse_benefits(get_attr(card, "benefits")),
        "is_active": get_attr(card, "is_active", default=True),
        "card_benefits": [serialize_card_benefit(b) for b in benefits],
        "promotions": [serialize_promotion(p) for p in promotions],
    }


@app.get("/bank/marketing")
def get_bank_marketing_info(db: Session = Depends(get_db)):
    CardModel = get_model("Card")
    PromotionModel = get_model("Promotion")

    cards = query_all_if_model_exists(db, "Card")
    promotions = query_all_if_model_exists(db, "Promotion") if PromotionModel else []

    result = {
        "bank_name": BANK_NAME,
        "available_cards": [serialize_card(card) for card in cards],
        "active_promotions": [serialize_promotion(promo) for promo in promotions]
    }
    return jsonable_encoder(result)


@app.get("/user/assets/{email}")
def get_user_integrated_assets(email: str, db: Session = Depends(get_db)):
    UserModel = get_model("User")
    AccountModel = get_model("Account")
    TransactionModel = get_model("Transaction")

    if UserModel is None or AccountModel is None:
        raise HTTPException(status_code=500, detail="필수 모델(User/Account)이 없습니다.")

    user = db.query(UserModel).filter(UserModel.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="해당 이메일의 사용자를 찾을 수 없습니다.")

    accounts = db.query(AccountModel).filter(AccountModel.user_id == user.user_id).all()
    all_cards = []
    all_transactions = []

    for acc in accounts:
        acc_cards = get_attr(acc, "cards", default=[]) or []
        all_cards.extend(acc_cards)

    if accounts and TransactionModel is not None:
        account_ids = [acc.account_id for acc in accounts]
        all_transactions = db.query(TransactionModel).filter(
            TransactionModel.account_id.in_(account_ids)
        ).order_by(TransactionModel.created_at.desc()).limit(30).all()

    result = {
        "bank": BANK_NAME,
        "user_name": get_attr(user, "username"),
        "accounts": [serialize_account(acc) for acc in accounts],
        "my_cards": [serialize_user_card(card) for card in all_cards],
        "transactions": [serialize_transaction(tx) for tx in all_transactions]
    }
    return jsonable_encoder(result)


@app.get("/api/v1/catalog/cards")
def get_card_catalog(db: Session = Depends(get_db)):
    CardModel = get_model("Card")
    CardBenefitModel = get_model("CardBenefit")
    PromotionModel = get_model("Promotion")

    if CardModel is None:
        raise HTTPException(status_code=500, detail="Card 모델이 없습니다.")

    cards = query_all_if_model_exists(db, "Card")
    card_benefits = query_all_if_model_exists(db, "CardBenefit") if CardBenefitModel else []
    promotions = query_all_if_model_exists(db, "Promotion") if PromotionModel else []

    benefits_map = {}
    for benefit in card_benefits:
        benefit_card_id = get_attr(benefit, "card_id")
        if benefit_card_id is None:
            continue
        card_id = str(benefit_card_id)
        benefits_map.setdefault(card_id, []).append(benefit)

    catalog = []
    for card in cards:
        card_id = str(get_attr(card, "card_id"))
        matched_benefits = benefits_map.get(card_id, [])
        matched_promotions = find_promotions_for_card(card, promotions)

        catalog.append(build_card_catalog_item(card, matched_benefits, matched_promotions))

    result = {
        "bank_code": BANK_CODE,
        "cards": catalog,
        "count": len(catalog)
    }
    return jsonable_encoder(result)


@app.get("/api/v1/catalog/cards/{card_id}")
def get_card_catalog_detail(card_id: str, db: Session = Depends(get_db)):
    CardModel = get_model("Card")
    CardBenefitModel = get_model("CardBenefit")
    PromotionModel = get_model("Promotion")

    if CardModel is None:
        raise HTTPException(status_code=500, detail="Card 모델이 없습니다.")

    card = db.query(CardModel).filter(
        CardModel.card_id == card_id,
        CardModel.is_active == True
    ).first()

    if not card:
        raise HTTPException(status_code=404, detail="해당 카드 상품을 찾을 수 없습니다.")

    if CardBenefitModel is not None:
        benefits = db.query(CardBenefitModel).filter(
            CardBenefitModel.card_id == get_attr(card, "card_id"),
            CardBenefitModel.is_active == True
        ).all()
    else:
        benefits = []

    promotions = query_all_if_model_exists(db, "Promotion") if PromotionModel else []
    matched_promotions = find_promotions_for_card(card, promotions)

    result = build_card_catalog_item(card, benefits, matched_promotions)
    return jsonable_encoder(result)