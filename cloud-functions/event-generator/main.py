import os
import json
import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
import random
from google.cloud import pubsub_v1
import uuid
from demo_scenarios import DemoScenarios

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Event Generator Service",
    description="Generates sample events for real-time data pipeline demonstration",
    version="1.0.0"
)

# Initialize Pub/Sub publisher
publisher = pubsub_v1.PublisherClient()

# Global state for background tasks
generation_tasks = {}

class GenerationConfig(BaseModel):
    """Configuration for event generation"""
    events_per_minute: int = 60
    duration_minutes: int = 10
    event_types: list = ["order", "inventory", "user_activity"]
    environment: str = "dev"

class EventGenerator:
    """Event generator with realistic data"""
    
    def __init__(self, project_id: str, environment: str = "dev"):
        self.project_id = project_id
        self.environment = environment
        self.topic_path = publisher.topic_path(project_id, f"{environment}-backend-events-topic")
        
        # Sample data for realistic generation
        self.customers = [f"customer-{i:03d}" for i in range(1, 101)]
        self.products = [
            {"id": "prod-001", "name": "Laptop Computer", "price": 999.99, "category": "electronics"},
            {"id": "prod-002", "name": "Wireless Headphones", "price": 129.99, "category": "electronics"},
            {"id": "prod-003", "name": "Coffee Maker", "price": 79.99, "category": "appliances"},
            {"id": "prod-004", "name": "Running Shoes", "price": 89.99, "category": "footwear"},
            {"id": "prod-005", "name": "Smartphone", "price": 699.99, "category": "electronics"},
            {"id": "prod-006", "name": "Desk Chair", "price": 199.99, "category": "furniture"},
            {"id": "prod-007", "name": "Water Bottle", "price": 24.99, "category": "lifestyle"},
            {"id": "prod-008", "name": "Gaming Mouse", "price": 59.99, "category": "electronics"},
            {"id": "prod-009", "name": "Yoga Mat", "price": 39.99, "category": "fitness"},
            {"id": "prod-010", "name": "Backpack", "price": 49.99, "category": "accessories"}
        ]
        self.warehouses = ["wh-us-east", "wh-us-west", "wh-us-central", "wh-eu-west", "wh-asia-pacific"]
        self.cities = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose"]
        self.countries = ["US", "CA", "UK", "DE", "FR", "AU", "JP"]
        self.user_agents = [
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
            "Mozilla/5.0 (Android 11; Mobile; rv:89.0) Gecko/89.0 Firefox/89.0"
        ]
        self.platforms = ["web", "mobile", "tablet"]
        self.activity_types = ["login", "logout", "view_product", "add_to_cart", "remove_from_cart"]
        self.order_statuses = ["pending", "processing", "shipped", "delivered"]
        self.inventory_reasons = ["restock", "sale", "return", "damage"]
    
    def generate_order_event(self) -> Dict[str, Any]:
        """Generate a realistic order event"""
        customer_id = random.choice(self.customers)
        order_id = f"ord-{uuid.uuid4().hex[:8]}"
        
        # Select 1-3 random products
        num_items = random.randint(1, 3)
        selected_products = random.sample(self.products, num_items)
        
        items = []
        total_amount = 0
        
        for product in selected_products:
            quantity = random.randint(1, 3)
            price = product["price"]
            items.append({
                "product_id": product["id"],
                "product_name": product["name"],
                "quantity": quantity,
                "price": price
            })
            total_amount += price * quantity
        
        # Generate timestamp within last hour
        now = datetime.utcnow()
        order_time = now - timedelta(minutes=random.randint(0, 60))
        
        return {
            "event_type": "order",
            "order_id": order_id,
            "customer_id": customer_id,
            "order_date": order_time.isoformat() + "Z",
            "status": random.choice(self.order_statuses),
            "items": items,
            "shipping_address": {
                "street": f"{random.randint(100, 9999)} {random.choice(['Main', 'Oak', 'Pine', 'Maple', 'Cedar'])} St",
                "city": random.choice(self.cities),
                "country": random.choice(self.countries)
            },
            "total_amount": round(total_amount, 2)
        }
    
    def generate_inventory_event(self) -> Dict[str, Any]:
        """Generate a realistic inventory event"""
        product = random.choice(self.products)
        warehouse = random.choice(self.warehouses)
        reason = random.choice(self.inventory_reasons)
        
        # Adjust quantity change based on reason
        if reason == "restock":
            quantity_change = random.randint(10, 100)
        elif reason == "sale":
            quantity_change = random.randint(-50, -1)
        elif reason == "return":
            quantity_change = random.randint(1, 20)
        else:  # damage
            quantity_change = random.randint(-10, -1)
        
        timestamp = datetime.utcnow() - timedelta(minutes=random.randint(0, 30))
        
        return {
            "event_type": "inventory",
            "inventory_id": f"inv-{uuid.uuid4().hex[:8]}",
            "product_id": product["id"],
            "warehouse_id": warehouse,
            "quantity_change": quantity_change,
            "reason": reason,
            "timestamp": timestamp.isoformat() + "Z"
        }
    
    def generate_user_activity_event(self) -> Dict[str, Any]:
        """Generate a realistic user activity event"""
        user_id = f"user-{random.randint(1, 1000):04d}"
        activity_type = random.choice(self.activity_types)
        platform = random.choice(self.platforms)
        
        # Generate realistic IP address
        ip_address = f"{random.randint(192, 203)}.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}"
        
        timestamp = datetime.utcnow() - timedelta(minutes=random.randint(0, 15))
        
        return {
            "event_type": "user_activity",
            "user_id": user_id,
            "activity_type": activity_type,
            "ip_address": ip_address,
            "user_agent": random.choice(self.user_agents),
            "timestamp": timestamp.isoformat() + "Z",
            "metadata": {
                "session_id": f"sess-{uuid.uuid4().hex[:12]}",
                "platform": platform
            }
        }
    
    def generate_event(self, event_type: str) -> Dict[str, Any]:
        """Generate an event of the specified type"""
        generators = {
            "order": self.generate_order_event,
            "inventory": self.generate_inventory_event,
            "user_activity": self.generate_user_activity_event
        }
        
        generator = generators.get(event_type)
        if not generator:
            raise ValueError(f"Unknown event type: {event_type}")
        
        return generator()
    
    async def publish_event(self, event: Dict[str, Any]) -> bool:
        """Publish event to Pub/Sub"""
        try:
            message_data = json.dumps(event).encode('utf-8')
            future = publisher.publish(self.topic_path, message_data)
            
            # Wait for publish to complete
            message_id = future.result()
            logger.info(f"Published {event['event_type']} event with message ID: {message_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to publish event: {e}")
            return False

# Initialize generator
generator = None

def ensure_generator():
    """Ensure the generator is initialized, create if needed"""
    global generator
    if generator is None:
        project_id = os.environ.get("PROJECT_ID")
        environment = os.environ.get("ENVIRONMENT", "dev")
        
        if not project_id:
            raise HTTPException(status_code=500, detail="PROJECT_ID environment variable is required")
        
        generator = EventGenerator(project_id, environment)
        logger.info(f"Event generator initialized on demand for project: {project_id}, environment: {environment}")
    
    return generator

@app.on_event("startup")
async def startup_event():
    """Initialize the event generator on startup"""
    global generator
    try:
        project_id = os.environ.get("PROJECT_ID")
        environment = os.environ.get("ENVIRONMENT", "dev")
        
        if not project_id:
            logger.warning("PROJECT_ID environment variable not set, generator will be initialized on first use")
            return
        
        generator = EventGenerator(project_id, environment)
        logger.info(f"Event generator initialized for project: {project_id}, environment: {environment}")
    except Exception as e:
        logger.error(f"Failed to initialize generator during startup: {e}")
        # Don't fail startup, allow initialization on first use
        pass

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "event-generator",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

@app.get("/health")
async def health_check():
    """Detailed health check"""
    project_id = os.environ.get("PROJECT_ID", "not-set")
    environment = os.environ.get("ENVIRONMENT", "dev")
    
    return {
        "status": "healthy",
        "project_id": project_id,
        "environment": environment,
        "generator_initialized": generator is not None,
        "active_tasks": len(generation_tasks),
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

@app.post("/generate/single/{event_type}")
async def generate_single_event(event_type: str):
    """Generate and publish a single event"""
    try:
        gen = ensure_generator()
        event = gen.generate_event(event_type)
        success = await gen.publish_event(event)
        
        if success:
            return {
                "status": "success",
                "event_type": event_type,
                "event": event,
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to publish event")
            
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")

@app.post("/generate/batch")
async def generate_batch_events(config: GenerationConfig):
    """Generate a batch of events immediately"""
    try:
        gen = ensure_generator()
        results = []
        events_per_type = config.events_per_minute // len(config.event_types)
        
        for event_type in config.event_types:
            for _ in range(events_per_type):
                try:
                    event = gen.generate_event(event_type)
                    success = await gen.publish_event(event)
                    results.append({
                        "event_type": event_type,
                        "success": success,
                        "event_id": event.get("order_id") or event.get("inventory_id") or event.get("user_id", "unknown")
                    })
                    
                    # Small delay to avoid overwhelming
                    await asyncio.sleep(0.1)
                    
                except Exception as e:
                    logger.error(f"Error generating {event_type} event: {e}")
                    results.append({
                        "event_type": event_type,
                        "success": False,
                        "error": str(e)
                    })
        
        successful = len([r for r in results if r["success"]])
        
        return {
            "status": "completed",
            "total_events": len(results),
            "successful_events": successful,
            "failed_events": len(results) - successful,
            "results": results,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate batch events: {str(e)}")

async def continuous_generation_task(task_id: str, config: GenerationConfig):
    """Background task for continuous event generation"""
    logger.info(f"Starting continuous generation task {task_id}")
    
    total_events = config.events_per_minute * config.duration_minutes
    events_per_type = total_events // len(config.event_types)
    
    interval = 60.0 / config.events_per_minute  # seconds between events
    
    start_time = datetime.utcnow()
    end_time = start_time + timedelta(minutes=config.duration_minutes)
    
    event_count = 0
    
    try:
        gen = ensure_generator()
        while datetime.utcnow() < end_time and task_id in generation_tasks:
            for event_type in config.event_types:
                if datetime.utcnow() >= end_time or task_id not in generation_tasks:
                    break
                
                try:
                    event = gen.generate_event(event_type)
                    await gen.publish_event(event)
                    event_count += 1
                    
                    # Update task status
                    if task_id in generation_tasks:
                        generation_tasks[task_id]["events_generated"] = event_count
                        generation_tasks[task_id]["last_event_time"] = datetime.utcnow().isoformat() + "Z"
                    
                    await asyncio.sleep(interval / len(config.event_types))
                    
                except Exception as e:
                    logger.error(f"Error in continuous generation: {e}")
                    await asyncio.sleep(1)  # Brief pause on error
        
        # Mark task as completed
        if task_id in generation_tasks:
            generation_tasks[task_id]["status"] = "completed"
            generation_tasks[task_id]["end_time"] = datetime.utcnow().isoformat() + "Z"
            generation_tasks[task_id]["total_events"] = event_count
            
        logger.info(f"Continuous generation task {task_id} completed. Generated {event_count} events")
        
    except Exception as e:
        logger.error(f"Continuous generation task {task_id} failed: {e}")
        if task_id in generation_tasks:
            generation_tasks[task_id]["status"] = "failed"
            generation_tasks[task_id]["error"] = str(e)

@app.post("/generate/start")
async def start_continuous_generation(config: GenerationConfig, background_tasks: BackgroundTasks):
    """Start continuous event generation in the background"""
    try:
        gen = ensure_generator()
        task_id = f"task-{uuid.uuid4().hex[:8]}"
        
        # Store task metadata
        generation_tasks[task_id] = {
            "id": task_id,
            "status": "running",
            "config": config.dict(),
            "start_time": datetime.utcnow().isoformat() + "Z",
            "events_generated": 0,
            "last_event_time": None
        }
        
        # Start background task
        background_tasks.add_task(continuous_generation_task, task_id, config)
        
        return {
            "status": "started",
            "task_id": task_id,
            "config": config.dict(),
            "estimated_duration_minutes": config.duration_minutes,
            "estimated_total_events": config.events_per_minute * config.duration_minutes
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start generation: {str(e)}")

@app.get("/generate/status/{task_id}")
async def get_generation_status(task_id: str):
    """Get status of a generation task"""
    if task_id not in generation_tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    
    return generation_tasks[task_id]

@app.get("/generate/status")
async def get_all_generation_status():
    """Get status of all generation tasks"""
    return {
        "active_tasks": len(generation_tasks),
        "tasks": generation_tasks
    }

@app.delete("/generate/stop/{task_id}")
async def stop_generation_task(task_id: str):
    """Stop a specific generation task"""
    if task_id not in generation_tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # Remove task to signal it should stop
    task_info = generation_tasks.pop(task_id)
    task_info["status"] = "stopped"
    task_info["end_time"] = datetime.utcnow().isoformat() + "Z"
    
    return {
        "status": "stopped",
        "task_id": task_id,
        "task_info": task_info
    }

@app.delete("/generate/stop")
async def stop_all_generation_tasks():
    """Stop all active generation tasks"""
    stopped_tasks = list(generation_tasks.keys())
    
    for task_id in stopped_tasks:
        generation_tasks[task_id]["status"] = "stopped"
        generation_tasks[task_id]["end_time"] = datetime.utcnow().isoformat() + "Z"
    
    # Clear all tasks
    generation_tasks.clear()
    
    return {
        "status": "all_stopped",
        "stopped_task_count": len(stopped_tasks),
        "stopped_tasks": stopped_tasks
    }

@app.get("/sample/{event_type}")
async def get_sample_event(event_type: str):
    """Get a sample event without publishing it"""
    try:
        gen = ensure_generator()
        event = gen.generate_event(event_type)
        return {
            "event_type": event_type,
            "sample_event": event,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/scenarios")
async def get_demo_scenarios():
    """Get all available demo scenarios with descriptions"""
    return {
        "scenarios": DemoScenarios.get_all_scenarios(),
        "usage": "Use /scenarios/{scenario_name}/start to run a predefined scenario",
        "available_scenarios": list(DemoScenarios.get_all_scenarios().keys())
    }

@app.get("/scenarios/{scenario_name}")
async def get_demo_scenario(scenario_name: str):
    """Get details of a specific demo scenario"""
    try:
        all_scenarios = DemoScenarios.get_all_scenarios()
        if scenario_name not in all_scenarios:
            available = list(all_scenarios.keys())
            raise HTTPException(status_code=404, detail=f"Scenario not found. Available: {available}")
        
        return all_scenarios[scenario_name]
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/scenarios/{scenario_name}/start")
async def start_demo_scenario(scenario_name: str, background_tasks: BackgroundTasks):
    """Start a predefined demo scenario"""
    try:
        gen = ensure_generator()
        config = DemoScenarios.get_scenario(scenario_name)
        task_id = f"scenario-{scenario_name}-{uuid.uuid4().hex[:8]}"
        
        # Store task metadata with scenario info
        generation_tasks[task_id] = {
            "id": task_id,
            "scenario_name": scenario_name,
            "status": "running",
            "config": config.dict(),
            "start_time": datetime.utcnow().isoformat() + "Z",
            "events_generated": 0,
            "last_event_time": None
        }
        
        # Start background task
        background_tasks.add_task(continuous_generation_task, task_id, config)
        
        scenario_info = DemoScenarios.get_all_scenarios()[scenario_name]
        
        return {
            "status": "started",
            "task_id": task_id,
            "scenario_name": scenario_name,
            "scenario_description": scenario_info["description"],
            "config": config.dict(),
            "estimated_duration": scenario_info["duration"],
            "estimated_total_events": scenario_info["total_events"]
        }
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080) 