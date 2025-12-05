-- phpMyAdmin SQL Dump
-- version 5.2.0
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Dec 05, 2025 at 02:06 AM
-- Server version: 8.0.30
-- PHP Version: 8.2.28

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `trains_dw`
--

-- --------------------------------------------------------

--
-- Table structure for table `dim_customer`
--

CREATE TABLE `dim_customer` (
  `customer_key` int NOT NULL,
  `customer_id` varchar(50) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `customer_name` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `segment` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `city` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `state` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `country` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `dim_product`
--

CREATE TABLE `dim_product` (
  `product_key` int NOT NULL,
  `product_id` varchar(50) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `product_name` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `category` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `sub_category` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `dim_time`
--

CREATE TABLE `dim_time` (
  `time_key` int NOT NULL,
  `full_date` date DEFAULT NULL,
  `day` int DEFAULT NULL,
  `month` int DEFAULT NULL,
  `quarter` int DEFAULT NULL,
  `year` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `fact_sales`
--

CREATE TABLE `fact_sales` (
  `sales_key` int NOT NULL,
  `order_id` varchar(50) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `product_key` int DEFAULT NULL,
  `customer_key` int DEFAULT NULL,
  `time_key` int DEFAULT NULL,
  `sales` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `dim_customer`
--
ALTER TABLE `dim_customer`
  ADD PRIMARY KEY (`customer_key`);

--
-- Indexes for table `dim_product`
--
ALTER TABLE `dim_product`
  ADD PRIMARY KEY (`product_key`);

--
-- Indexes for table `dim_time`
--
ALTER TABLE `dim_time`
  ADD PRIMARY KEY (`time_key`);

--
-- Indexes for table `fact_sales`
--
ALTER TABLE `fact_sales`
  ADD PRIMARY KEY (`sales_key`),
  ADD KEY `product_key` (`product_key`),
  ADD KEY `customer_key` (`customer_key`),
  ADD KEY `fact_sales_ibfk_3` (`time_key`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `dim_customer`
--
ALTER TABLE `dim_customer`
  MODIFY `customer_key` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `dim_product`
--
ALTER TABLE `dim_product`
  MODIFY `product_key` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `dim_time`
--
ALTER TABLE `dim_time`
  MODIFY `time_key` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `fact_sales`
--
ALTER TABLE `fact_sales`
  MODIFY `sales_key` int NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `fact_sales`
--
ALTER TABLE `fact_sales`
  ADD CONSTRAINT `fact_sales_ibfk_1` FOREIGN KEY (`product_key`) REFERENCES `dim_product` (`product_key`),
  ADD CONSTRAINT `fact_sales_ibfk_2` FOREIGN KEY (`customer_key`) REFERENCES `dim_customer` (`customer_key`),
  ADD CONSTRAINT `fact_sales_ibfk_3` FOREIGN KEY (`time_key`) REFERENCES `dim_time` (`time_key`) ON DELETE RESTRICT ON UPDATE RESTRICT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
