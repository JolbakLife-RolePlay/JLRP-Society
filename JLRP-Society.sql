CREATE TABLE `society_moneywash` (
	`id` int NOT NULL AUTO_INCREMENT,
	`citizenid` varchar(60) NOT NULL,
	`identifier` varchar(255) NOT NULL,
	`society` varchar(60) NOT NULL,
	`amount` int NOT NULL,

	PRIMARY KEY (`id`),
	KEY `citizenid` (`citizenid`),
	KEY `identifier` (`identifier`)
) ENGINE=InnoDB;