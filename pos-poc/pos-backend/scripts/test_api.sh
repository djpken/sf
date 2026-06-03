#!/bin/bash

# API Testing Script
# This script tests all implemented API endpoints

set -e

API_BASE="http://localhost:8080/api/v1"
TOKEN=""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

function print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Test health check
function test_health() {
    print_info "Testing health check..."
    response=$(curl -s http://localhost:8080/health)
    if echo "$response" | grep -q "healthy"; then
        print_success "Health check passed"
    else
        print_error "Health check failed"
        exit 1
    fi
}

# Test login
function test_login() {
    print_info "Testing login..."
    response=$(curl -s -X POST "$API_BASE/auth/login" \
        -H "Content-Type: application/json" \
        -d '{
            "email": "admin@example.com",
            "password": "admin123"
        }')

    TOKEN=$(echo "$response" | jq -r '.data.token')

    if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
        print_success "Login successful"
        print_info "Token: ${TOKEN:0:20}..."
    else
        print_error "Login failed"
        echo "$response" | jq '.'
        exit 1
    fi
}

# Test PIN login
function test_pin_login() {
    print_info "Testing PIN login..."
    response=$(curl -s -X POST "$API_BASE/auth/pin-login" \
        -H "Content-Type: application/json" \
        -d '{
            "tenant_id": "11111111-1111-1111-1111-111111111111",
            "pin_code": "1234"
        }')

    pin_token=$(echo "$response" | jq -r '.data.token')

    if [ "$pin_token" != "null" ] && [ -n "$pin_token" ]; then
        print_success "PIN login successful"
    else
        print_error "PIN login failed"
        echo "$response" | jq '.'
    fi
}

# Test menu categories
function test_menu_categories() {
    print_info "Testing list menu categories..."
    response=$(curl -s "$API_BASE/menu/categories" \
        -H "Authorization: Bearer $TOKEN")

    count=$(echo "$response" | jq '.data | length')
    if [ "$count" -gt 0 ]; then
        print_success "Listed $count categories"
    else
        print_error "Failed to list categories"
    fi
}

# Test create category
function test_create_category() {
    print_info "Testing create category..."
    response=$(curl -s -X POST "$API_BASE/menu/categories" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "測試分類",
            "sort_order": 99
        }')

    category_id=$(echo "$response" | jq -r '.data.id')
    if [ "$category_id" != "null" ] && [ -n "$category_id" ]; then
        print_success "Created category: $category_id"
        echo "$category_id"
    else
        print_error "Failed to create category"
    fi
}

# Test menu items
function test_menu_items() {
    print_info "Testing list menu items..."
    response=$(curl -s "$API_BASE/menu/items" \
        -H "Authorization: Bearer $TOKEN")

    count=$(echo "$response" | jq '.data | length')
    if [ "$count" -gt 0 ]; then
        print_success "Listed $count menu items"
    else
        print_error "Failed to list menu items"
    fi
}

# Test create menu item
function test_create_menu_item() {
    print_info "Testing create menu item..."
    response=$(curl -s -X POST "$API_BASE/menu/items" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "測試商品",
            "description": "這是一個測試商品",
            "price": 99.99,
            "category_id": "44444444-4444-4444-4444-444444444441"
        }')

    item_id=$(echo "$response" | jq -r '.data.id')
    if [ "$item_id" != "null" ] && [ -n "$item_id" ]; then
        print_success "Created menu item: $item_id"
        echo "$item_id"
    else
        print_error "Failed to create menu item"
        echo "$response" | jq '.'
    fi
}

# Test get menu item by barcode
function test_get_item_by_barcode() {
    print_info "Testing get item by barcode..."
    response=$(curl -s "$API_BASE/menu/items/barcode/1001" \
        -H "Authorization: Bearer $TOKEN")

    item_name=$(echo "$response" | jq -r '.data.name')
    if [ "$item_name" != "null" ] && [ -n "$item_name" ]; then
        print_success "Found item: $item_name"
    else
        print_error "Failed to get item by barcode"
    fi
}

# Test create order
function test_create_order() {
    print_info "Testing create order..."
    response=$(curl -s -X POST "$API_BASE/orders" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "order_type": "dine_in",
            "table_id": "66666666-6666-6666-6666-666666666661",
            "items": [
                {
                    "item_id": "55555555-5555-5555-5555-555555555551",
                    "quantity": 2,
                    "options": {"sugar": "少糖", "ice": "去冰"}
                },
                {
                    "item_id": "55555555-5555-5555-5555-555555555555",
                    "quantity": 1
                }
            ]
        }')

    order_id=$(echo "$response" | jq -r '.data.id')
    if [ "$order_id" != "null" ] && [ -n "$order_id" ]; then
        print_success "Created order: $order_id"
        echo "$order_id"
    else
        print_error "Failed to create order"
        echo "$response" | jq '.'
    fi
}

# Test list orders
function test_list_orders() {
    print_info "Testing list orders..."
    response=$(curl -s "$API_BASE/orders" \
        -H "Authorization: Bearer $TOKEN")

    total=$(echo "$response" | jq -r '.data.total')
    if [ "$total" != "null" ]; then
        print_success "Listed orders, total: $total"
    else
        print_error "Failed to list orders"
    fi
}

# Test add payment
function test_add_payment() {
    local order_id=$1
    print_info "Testing add payment to order..."
    response=$(curl -s -X POST "$API_BASE/orders/$order_id/payments" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "method": "cash",
            "amount": 200,
            "received": 500
        }')

    payment_status=$(echo "$response" | jq -r '.data.payment_status')
    if [ "$payment_status" == "paid" ]; then
        print_success "Payment completed, order status: $payment_status"
    else
        print_error "Failed to add payment"
        echo "$response" | jq '.'
    fi
}

# Test daily sales
function test_daily_sales() {
    print_info "Testing get daily sales..."
    response=$(curl -s "$API_BASE/orders/sales/daily" \
        -H "Authorization: Bearer $TOKEN")

    total=$(echo "$response" | jq -r '.data.total_sales')
    if [ "$total" != "null" ]; then
        print_success "Daily sales: NT$ $total"
    else
        print_error "Failed to get daily sales"
    fi
}

# Main test flow
function main() {
    echo ""
    echo "=========================================="
    echo "  POS API Testing Script"
    echo "=========================================="
    echo ""

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it first (brew install jq)"
        exit 1
    fi

    # Check if server is running
    if ! curl -s http://localhost:8080/health > /dev/null; then
        print_error "Server is not running on http://localhost:8080"
        exit 1
    fi

    # Run tests
    test_health
    echo ""

    test_login
    test_pin_login
    echo ""

    test_menu_categories
    test_menu_items
    test_get_item_by_barcode
    echo ""

    # Create test data
    # test_create_category
    # test_create_menu_item
    # echo ""

    # Order tests
    order_id=$(test_create_order)
    test_list_orders
    echo ""

    # Payment test
    if [ -n "$order_id" ] && [ "$order_id" != "null" ]; then
        test_add_payment "$order_id"
    fi
    echo ""

    test_daily_sales
    echo ""

    echo "=========================================="
    print_success "All tests completed!"
    echo "=========================================="
}

main
