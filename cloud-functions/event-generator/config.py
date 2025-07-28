"""
Configuration classes for event generation
"""

from pydantic import BaseModel
from typing import List

class GenerationConfig(BaseModel):
    events_per_minute: int = 30
    duration_minutes: int = 5
    event_types: List[str] = ["order", "inventory", "user_activity"] 