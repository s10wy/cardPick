# hana/models.py
from sqlalchemy import (
    Column,
    String,
    Numeric,
    Boolean,
    ForeignKey,
    TIMESTAMP,
    Date,
    Integer,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship
from database import Base
import uuid


class User(Base):
    __tablename__ = "users"

    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, nullable=False)
    username = Column(String)


class Account(Base):
    __tablename__ = "accounts"

    account_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id", ondelete="CASCADE"),
    )
    account_number = Column(String, unique=True, nullable=False)
    account_type = Column(String, nullable=False)
    balance = Column(Numeric(15, 2), default=0.00)
    status = Column(String, default="ACTIVE")
    created_at = Column(TIMESTAMP(timezone=True))

    cards = relationship("Users_Cards", back_populates="account")


class Card(Base):
    __tablename__ = "cards"

    card_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    card_name = Column(String, nullable=False)
    card_type = Column(String)  # CREDIT / CHECK 등
    limit_amount = Column(Numeric(15, 2))
    benefits = Column(JSONB)  # 요약형 혜택 JSON
    is_active = Column(Boolean, default=True)

    # 새 컬럼들 (PostgreSQL용)
    annual_fee_domestic = Column(Numeric(15, 2), default=0.00)
    annual_fee_overseas = Column(Numeric(15, 2), default=0.00)
    brand_name = Column(String(30))  # VISA / MASTER / LOCAL 등
    card_product_status = Column(String(20), default="ACTIVE")
    target_segment = Column(String(30))  # STUDENT / YOUTH / PREMIUM 등
    income_requirement_min = Column(Numeric(15, 2))
    credit_score_requirement = Column(String(50))
    domestic_only = Column(Boolean, default=False)
    online_only = Column(Boolean, default=False)


class CardBenefit(Base):
    __tablename__ = "card_benefits"

    card_benefit_id = Column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    card_id = Column(
        UUID(as_uuid=True),
        ForeignKey("cards.card_id", ondelete="CASCADE"),
        nullable=False,
    )
    category_code = Column(String, nullable=False)
    merchant_name = Column(String)
    benefit_type = Column(String, nullable=False)  # RATE / AMOUNT / POINT / FREE 등
    benefit_value = Column(Numeric(15, 2))
    benefit_unit = Column(String)  # PERCENT / AMOUNT / POINT / FREE 등
    description = Column(String)
    is_active = Column(Boolean, default=True)

    # 조건용 컬럼들
    previous_month_spend_min = Column(Numeric(15, 2))
    previous_month_spend_max = Column(Numeric(15, 2))
    monthly_benefit_limit = Column(Numeric(15, 2))
    daily_benefit_limit = Column(Numeric(15, 2))
    per_transaction_min_amount = Column(Numeric(15, 2))
    per_transaction_max_amount = Column(Numeric(15, 2))
    max_benefit_count_per_month = Column(Integer)
    priority = Column(Integer, default=100)
    eligible_channels = Column(String(200))  # 'OFFLINE,ONLINE' 같은 문자열
    eligible_days = Column(String(50))  # 'MON,TUE,WED,...'
    eligible_time_start = Column(TIMESTAMP(timezone=False))
    eligible_time_end = Column(TIMESTAMP(timezone=False))
    domestic_only = Column(Boolean, default=False)
    overseas_only = Column(Boolean, default=False)
    is_exclusive = Column(Boolean, default=False)


class Promotion(Base):
    __tablename__ = "promotions"

    promotion_id = Column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    title = Column(String, nullable=False)
    content = Column(String)
    start_date = Column(TIMESTAMP(timezone=True))
    end_date = Column(TIMESTAMP(timezone=True))
    is_active = Column(Boolean, default=True)
    category = Column(String, nullable=False)  # 'FOOD(맥도날드)' 등
    benefit_type = Column(String, default="RATE")
    benefit_value = Column(Numeric(15, 2), default=0.00)
    target_cards = Column(String)  # '하나 트래블로그 체크카드, 내맘대로 쁨' 등
    merchant_name = Column(String)
    category_code = Column(String)

    # 조건용 컬럼들
    promotion_channel = Column(String(30))  # ONLINE / OFFLINE / APP 등
    promotion_min_amount = Column(Numeric(15, 2))
    promotion_max_benefit_amount = Column(Numeric(15, 2))
    promotion_max_count = Column(Integer)
    coupon_required = Column(Boolean, default=False)
    app_event_only = Column(Boolean, default=False)
    stackable_with_base_benefit = Column(Boolean, default=False)
    priority = Column(Integer, default=100)


class Users_Cards(Base):
    __tablename__ = "users_cards"

    account_id = Column(
        UUID(as_uuid=True),
        ForeignKey("accounts.account_id", ondelete="CASCADE"),
        nullable=False,
    )
    card_number = Column(String, primary_key=True, nullable=False)
    card_name = Column(String)
    card_type = Column(String)
    cvc = Column(String)
    expiry_date = Column(Date)
    limit_amount = Column(Numeric(15, 2))
    benefits = Column(JSONB)
    is_active = Column(Boolean, default=True)

    account = relationship("Account", back_populates="cards")


class Transaction(Base):
    __tablename__ = "users_transactions"

    transaction_id = Column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    from_account = Column(String, nullable=False)
    to_account = Column(String, nullable=False)
    amount = Column(Numeric(15, 2), nullable=False)
    transaction_type = Column(String)
    category = Column(String)
    created_at = Column(TIMESTAMP(timezone=True))
    account_id = Column(
        UUID(as_uuid=True),
        ForeignKey("accounts.account_id", ondelete="CASCADE"),
    )
    category_code = Column(String)


class CardBenefitRule(Base):
    __tablename__ = "card_benefit_rules"

    benefit_rule_id = Column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    card_benefit_id = Column(
        UUID(as_uuid=True),
        ForeignKey("card_benefits.card_benefit_id", ondelete="CASCADE"),
        nullable=False,
    )

    previous_month_spend_min = Column(Numeric(15, 2))
    previous_month_spend_max = Column(Numeric(15, 2))
    monthly_benefit_limit = Column(Numeric(15, 2))
    daily_benefit_limit = Column(Numeric(15, 2))
    per_transaction_min_amount = Column(Numeric(15, 2))
    per_transaction_max_amount = Column(Numeric(15, 2))
    max_benefit_count_per_month = Column(Integer)
    priority = Column(Integer, default=100, nullable=False)
    eligible_channels = Column(String(200))
    eligible_days = Column(String(50))
    eligible_time_start = Column(TIMESTAMP(timezone=False))
    eligible_time_end = Column(TIMESTAMP(timezone=False))
    domestic_only = Column(Boolean, default=False)
    overseas_only = Column(Boolean, default=False)
    is_exclusive = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP(timezone=True))
    updated_at = Column(TIMESTAMP(timezone=True))


class PromotionRule(Base):
    __tablename__ = "promotion_rules"

    promotion_rule_id = Column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    promotion_id = Column(
        UUID(as_uuid=True),
        ForeignKey("promotions.promotion_id", ondelete="CASCADE"),
        nullable=False,
    )

    promotion_channel = Column(String(30))
    promotion_min_amount = Column(Numeric(15, 2))
    promotion_max_benefit_amount = Column(Numeric(15, 2))
    promotion_max_count = Column(Integer)
    coupon_required = Column(Boolean, default=False)
    app_event_only = Column(Boolean, default=False)
    stackable_with_base_benefit = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP(timezone=True))
    updated_at = Column(TIMESTAMP(timezone=True))