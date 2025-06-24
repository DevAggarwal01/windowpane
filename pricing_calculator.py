"""
Pricing calculator module for video streaming services.
Contains functions to calculate upload, storage, and streaming costs.
"""

def calculate_upload_cost(type: str, minutes: float) -> float:
    """
    Calculate the upload cost for video content.
    
    Args:
        type (str): The type of content (e.g., 'live')
        minutes (float): Duration of the video in minutes
        
    Returns:
        float: The upload cost in USD
    """
    if type.lower() == 'live':
        return minutes * 0.032
    else:
        raise ValueError("Unsupported content type for upload cost calculation")

def calculate_storage_cost(type: str, minutes: float) -> float:
    """
    Calculate the storage cost per month for video content.
    
    Args:
        type (str): The type of content (e.g., 'live')
        minutes (float): Duration of the video in minutes
        
    Returns:
        float: The storage cost per month in USD
    """
    if type.lower() == 'live':
        return minutes * 0.003
    else:
        raise ValueError("Unsupported content type for storage cost calculation")

def calculate_streaming_cost(type: str, minutes: float) -> float:
    """
    Calculate the streaming cost per stream for video content.
    
    Args:
        type (str): The type of content (e.g., 'live')
        minutes (float): Duration of the video in minutes
        
    Returns:
        float: The streaming cost per stream in USD
    """
    if type.lower() == 'live':
        return minutes * 0.00096
    else:
        raise ValueError("Unsupported content type for streaming cost calculation")

def calculate_platform_margin_percent(price: float) -> float:
    """
    Calculate the platform margin percentage based on price using a piecewise linear function.
    
    Args:
        price (float): The ticket price in USD
        
    Returns:
        float: The platform margin percentage (between 0 and 1)
    """
    if price <= 0:
        return 0.0
    elif price <= 2:
        return 0.30  # 30% flat for $1-$2
    elif price <= 5:
        # Linear interpolation from 30% to 20% between $2 and $5
        return 0.30 - (0.10 * (price - 2) / 3)
    elif price <= 10:
        # Linear interpolation from 20% to 12% between $5 and $10
        return 0.20 - (0.08 * (price - 5) / 5)
    else:
        return 0.10  # 10% flat for $10+

def calculate_revenue_breakdown(price: float, minutes: float) -> dict:
    """
    Calculate the complete revenue breakdown including streaming costs, platform cut, and creator payout.
    
    Args:
        price (float): The ticket price in USD
        minutes (float): Duration of the video in minutes
        
    Returns:
        dict: A dictionary containing the revenue breakdown components
    """
    if price < 0:
        raise ValueError("Price cannot be negative")
        
    stream_cost = minutes * 0.00096
    base_cut = price - stream_cost
    
    if base_cut < 0:
        base_cut = 0
        platform_cut = 0
        creator_payout = 0
    else:
        platform_margin = calculate_platform_margin_percent(price)
        platform_cut = base_cut * platform_margin
        creator_payout = base_cut - platform_cut
    
    return {
        "ticket_price": price,
        "stream_cost": stream_cost,
        "base_cut": base_cut,
        "platform_margin_percent": calculate_platform_margin_percent(price) * 100,  # Convert to percentage
        "platform_cut": platform_cut,
        "creator_payout": creator_payout
    } 