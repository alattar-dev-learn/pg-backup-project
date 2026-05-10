-- ============================================
-- Sample Database: Online Shop
-- ============================================

-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Products table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    stock INT DEFAULT 0
);

-- Orders table
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    product_id INT REFERENCES products(id),
    quantity INT NOT NULL,
    order_date TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- Sample Data
-- ============================================

INSERT INTO users (name, email) VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com'),
    ('Carol White', 'carol@example.com'),
    ('David Brown', 'david@example.com'),
    ('Eve Davis', 'eve@example.com');

INSERT INTO products (name, price, stock) VALUES
    ('Laptop Pro 15"', 1299.99, 50),
    ('Wireless Mouse', 29.99, 200),
    ('USB-C Hub', 49.99, 150),
    ('Mechanical Keyboard', 89.99, 75),
    ('Monitor 27"', 399.99, 30);

INSERT INTO orders (user_id, product_id, quantity) VALUES
    (1, 1, 1),
    (1, 2, 2),
    (2, 3, 1),
    (3, 4, 1),
    (4, 5, 1),
    (5, 2, 3),
    (2, 1, 1);
