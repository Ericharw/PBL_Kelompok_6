-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Waktu pembuatan: 03 Des 2025 pada 09.04
-- Versi server: 10.4.32-MariaDB
-- Versi PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `train_dw`
--

-- --------------------------------------------------------

--
-- Struktur dari tabel `dim_customer`
--

CREATE TABLE `dim_customer` (
  `customer_key` int(11) NOT NULL,
  `customer_id` varchar(50) DEFAULT NULL,
  `customer_name` varchar(255) DEFAULT NULL,
  `segment` varchar(100) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `state` varchar(100) DEFAULT NULL,
  `country` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `dim_product`
--

CREATE TABLE `dim_product` (
  `product_key` int(11) NOT NULL,
  `product_id` varchar(50) DEFAULT NULL,
  `product_name` varchar(255) DEFAULT NULL,
  `category` varchar(100) DEFAULT NULL,
  `sub_category` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `dim_store`
--

CREATE TABLE `dim_store` (
  `store_key` int(11) NOT NULL,
  `store_id` varchar(50) DEFAULT NULL,
  `store_name` varchar(255) DEFAULT NULL,
  `region` varchar(100) DEFAULT NULL,
  `manager` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `dim_time`
--

CREATE TABLE `dim_time` (
  `time_key` int(11) NOT NULL,
  `full_date` date DEFAULT NULL,
  `day` int(11) DEFAULT NULL,
  `month` int(11) DEFAULT NULL,
  `quarter` int(11) DEFAULT NULL,
  `year` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Struktur dari tabel `fact_sales`
--

CREATE TABLE `fact_sales` (
  `sales_key` int(11) NOT NULL,
  `order_id` varchar(50) DEFAULT NULL,
  `product_key` int(11) DEFAULT NULL,
  `customer_key` int(11) DEFAULT NULL,
  `store_key` int(11) DEFAULT NULL,
  `time_key` int(11) DEFAULT NULL,
  `quantity` int(11) DEFAULT NULL,
  `sales` decimal(10,2) DEFAULT NULL,
  `profit` decimal(10,2) DEFAULT NULL,
  `discount` decimal(5,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Indexes for dumped tables
--

--
-- Indeks untuk tabel `dim_customer`
--
ALTER TABLE `dim_customer`
  ADD PRIMARY KEY (`customer_key`);

--
-- Indeks untuk tabel `dim_product`
--
ALTER TABLE `dim_product`
  ADD PRIMARY KEY (`product_key`);

--
-- Indeks untuk tabel `dim_store`
--
ALTER TABLE `dim_store`
  ADD PRIMARY KEY (`store_key`);

--
-- Indeks untuk tabel `dim_time`
--
ALTER TABLE `dim_time`
  ADD PRIMARY KEY (`time_key`);

--
-- Indeks untuk tabel `fact_sales`
--
ALTER TABLE `fact_sales`
  ADD PRIMARY KEY (`sales_key`),
  ADD KEY `product_key` (`product_key`),
  ADD KEY `customer_key` (`customer_key`),
  ADD KEY `store_key` (`store_key`),
  ADD KEY `time_key` (`time_key`);

--
-- AUTO_INCREMENT untuk tabel yang dibuang
--

--
-- AUTO_INCREMENT untuk tabel `dim_customer`
--
ALTER TABLE `dim_customer`
  MODIFY `customer_key` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `dim_product`
--
ALTER TABLE `dim_product`
  MODIFY `product_key` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `dim_store`
--
ALTER TABLE `dim_store`
  MODIFY `store_key` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `dim_time`
--
ALTER TABLE `dim_time`
  MODIFY `time_key` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT untuk tabel `fact_sales`
--
ALTER TABLE `fact_sales`
  MODIFY `sales_key` int(11) NOT NULL AUTO_INCREMENT;

--
-- Ketidakleluasaan untuk tabel pelimpahan (Dumped Tables)
--

--
-- Ketidakleluasaan untuk tabel `fact_sales`
--
ALTER TABLE `fact_sales`
  ADD CONSTRAINT `fact_sales_ibfk_1` FOREIGN KEY (`product_key`) REFERENCES `dim_product` (`product_key`),
  ADD CONSTRAINT `fact_sales_ibfk_2` FOREIGN KEY (`customer_key`) REFERENCES `dim_customer` (`customer_key`),
  ADD CONSTRAINT `fact_sales_ibfk_3` FOREIGN KEY (`store_key`) REFERENCES `dim_store` (`store_key`),
  ADD CONSTRAINT `fact_sales_ibfk_4` FOREIGN KEY (`time_key`) REFERENCES `dim_time` (`time_key`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
