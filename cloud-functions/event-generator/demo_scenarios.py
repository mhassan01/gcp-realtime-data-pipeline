"""
Demo scenarios for event generation with predefined configurations
"""

from typing import Dict, Any
from config import GenerationConfig

class DemoScenarios:
    """Predefined demo scenarios for different use cases"""
    
    @staticmethod
    def get_scenario(scenario_name: str) -> GenerationConfig:
        """Get a predefined scenario configuration"""
        scenarios = {
            "light_demo": DemoScenarios.light_demo(),
            "moderate_load": DemoScenarios.moderate_load(),
            "heavy_load": DemoScenarios.heavy_load(),
            "burst_test": DemoScenarios.burst_test(),
            "sustained_demo": DemoScenarios.sustained_demo(),
            "stress_test": DemoScenarios.stress_test(),
            "quick_sample": DemoScenarios.quick_sample()
        }
        
        scenario = scenarios.get(scenario_name)
        if not scenario:
            available = list(scenarios.keys())
            raise ValueError(f"Unknown scenario: {scenario_name}. Available: {available}")
        
        return scenario
    
    @staticmethod
    def light_demo() -> GenerationConfig:
        """Light demo - 30 events/min for 5 minutes (150 total events)"""
        return GenerationConfig(
            events_per_minute=30,
            duration_minutes=5,
            event_types=["order", "inventory", "user_activity"],
            environment="dev"
        )
    
    @staticmethod
    def moderate_load() -> GenerationConfig:
        """Moderate load - 60 events/min for 10 minutes (600 total events)"""
        return GenerationConfig(
            events_per_minute=60,
            duration_minutes=10,
            event_types=["order", "inventory", "user_activity"],
            environment="dev"
        )
    
    @staticmethod
    def heavy_load() -> GenerationConfig:
        """Heavy load - 120 events/min for 15 minutes (1,800 total events)"""
        return GenerationConfig(
            events_per_minute=120,
            duration_minutes=15,
            event_types=["order", "inventory", "user_activity"],
            environment="dev"
        )
    
    @staticmethod
    def burst_test() -> GenerationConfig:
        """Burst test - 300 events/min for 3 minutes (900 total events)"""
        return GenerationConfig(
            events_per_minute=300,
            duration_minutes=3,
            event_types=["order", "inventory", "user_activity"],
            environment="dev"
        )
    
    @staticmethod
    def sustained_demo() -> GenerationConfig:
        """Sustained demo - 90 events/min for 30 minutes (2,700 total events)"""
        return GenerationConfig(
            events_per_minute=90,
            duration_minutes=30,
            event_types=["order", "inventory", "user_activity"],
            environment="dev"
        )
    
    @staticmethod
    def stress_test() -> GenerationConfig:
        """Stress test - 600 events/min for 10 minutes (6,000 total events)"""
        return GenerationConfig(
            events_per_minute=600,
            duration_minutes=10,
            event_types=["order", "inventory", "user_activity"],
            environment="dev"
        )
    
    @staticmethod
    def quick_sample() -> GenerationConfig:
        """Quick sample - 12 events/min for 1 minute (12 total events)"""
        return GenerationConfig(
            events_per_minute=12,
            duration_minutes=1,
            event_types=["order", "inventory", "user_activity"],
            environment="dev"
        )
    
    @staticmethod
    def orders_only() -> GenerationConfig:
        """Orders only - 60 events/min for 5 minutes (300 order events)"""
        return GenerationConfig(
            events_per_minute=60,
            duration_minutes=5,
            event_types=["order"],
            environment="dev"
        )
    
    @staticmethod
    def inventory_only() -> GenerationConfig:
        """Inventory only - 60 events/min for 5 minutes (300 inventory events)"""
        return GenerationConfig(
            events_per_minute=60,
            duration_minutes=5,
            event_types=["inventory"],
            environment="dev"
        )
    
    @staticmethod
    def user_activity_only() -> GenerationConfig:
        """User activity only - 60 events/min for 5 minutes (300 activity events)"""
        return GenerationConfig(
            events_per_minute=60,
            duration_minutes=5,
            event_types=["user_activity"],
            environment="dev"
        )
    
    @staticmethod
    def get_all_scenarios() -> Dict[str, Dict[str, Any]]:
        """Get all available scenarios with descriptions"""
        return {
            "light_demo": {
                "config": DemoScenarios.light_demo(),
                "description": "Light demo - 30 events/min for 5 minutes (150 total events)",
                "use_case": "Initial testing and basic demonstration",
                "duration": "5 minutes",
                "total_events": 150
            },
            "moderate_load": {
                "config": DemoScenarios.moderate_load(),
                "description": "Moderate load - 60 events/min for 10 minutes (600 total events)",
                "use_case": "Standard demo with realistic load",
                "duration": "10 minutes",
                "total_events": 600
            },
            "heavy_load": {
                "config": DemoScenarios.heavy_load(),
                "description": "Heavy load - 120 events/min for 15 minutes (1,800 total events)",
                "use_case": "Demonstrate pipeline handling higher throughput",
                "duration": "15 minutes",
                "total_events": 1800
            },
            "burst_test": {
                "config": DemoScenarios.burst_test(),
                "description": "Burst test - 300 events/min for 3 minutes (900 total events)",
                "use_case": "Test pipeline resilience with traffic spikes",
                "duration": "3 minutes",
                "total_events": 900
            },
            "sustained_demo": {
                "config": DemoScenarios.sustained_demo(),
                "description": "Sustained demo - 90 events/min for 30 minutes (2,700 total events)",
                "use_case": "Long-running demo for comprehensive testing",
                "duration": "30 minutes",
                "total_events": 2700
            },
            "stress_test": {
                "config": DemoScenarios.stress_test(),
                "description": "Stress test - 600 events/min for 10 minutes (6,000 total events)",
                "use_case": "Maximum load testing and performance validation",
                "duration": "10 minutes",
                "total_events": 6000
            },
            "quick_sample": {
                "config": DemoScenarios.quick_sample(),
                "description": "Quick sample - 12 events/min for 1 minute (12 total events)",
                "use_case": "Very quick test to verify pipeline is working",
                "duration": "1 minute",
                "total_events": 12
            },
            "orders_only": {
                "config": DemoScenarios.orders_only(),
                "description": "Orders only - 60 events/min for 5 minutes (300 order events)",
                "use_case": "Focus on order processing and analysis",
                "duration": "5 minutes",
                "total_events": 300
            },
            "inventory_only": {
                "config": DemoScenarios.inventory_only(),
                "description": "Inventory only - 60 events/min for 5 minutes (300 inventory events)",
                "use_case": "Focus on inventory tracking and warehouse analytics",
                "duration": "5 minutes",
                "total_events": 300
            },
            "user_activity_only": {
                "config": DemoScenarios.user_activity_only(),
                "description": "User activity only - 60 events/min for 5 minutes (300 activity events)",
                "use_case": "Focus on user behavior and engagement analytics",
                "duration": "5 minutes",
                "total_events": 300
            }
        } 