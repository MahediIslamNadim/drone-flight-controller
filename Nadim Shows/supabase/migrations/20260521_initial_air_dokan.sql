create extension if not exists "pgcrypto";

create table if not exists brands (
  id uuid primary key default gen_random_uuid(),
  name varchar(100) not null,
  slug varchar(100) unique not null,
  logo_url text,
  is_active boolean default true,
  created_at timestamp with time zone default now()
);

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  name varchar(100) not null,
  slug varchar(100) unique not null,
  is_active boolean default true,
  created_at timestamp with time zone default now()
);

create table if not exists shoes (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid references brands(id),
  category_id uuid references categories(id),
  name_bn varchar(200) not null,
  name_en varchar(200) not null,
  price numeric(10, 2) not null,
  image_urls text[] default '{}',
  colors varchar(50)[],
  materials varchar(100)[],
  style_type varchar(50),
  gender varchar(20),
  stock_status varchar(20) default 'in_stock',
  is_active boolean default true,
  created_at timestamp with time zone default now()
);

create table if not exists shoe_sizes (
  id uuid primary key default gen_random_uuid(),
  shoe_id uuid references shoes(id) on delete cascade,
  size varchar(10) not null,
  stock_quantity integer default 0,
  is_available boolean default true,
  unique (shoe_id, size)
);

create table if not exists sales (
  id uuid primary key default gen_random_uuid(),
  shoe_id uuid references shoes(id) on delete cascade,
  shoe_size_id uuid references shoe_sizes(id) on delete set null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(10, 2) not null,
  total_price numeric(10, 2) not null,
  sold_at timestamp with time zone default now()
);

insert into brands (name, slug)
values
  ('Bata', 'bata'),
  ('Apex', 'apex'),
  ('Nike', 'nike'),
  ('Adidas', 'adidas'),
  ('Lotto', 'lotto'),
  ('Power', 'power'),
  ('Sprint', 'sprint'),
  ('Unknown', 'unknown')
on conflict (slug) do nothing;

insert into categories (name, slug)
values
  ('Formal', 'formal'),
  ('Casual', 'casual'),
  ('Sports', 'sports'),
  ('Sandal', 'sandal'),
  ('Boot', 'boot'),
  ('Slipper', 'slipper')
on conflict (slug) do nothing;
