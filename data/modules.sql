DROP TABLE IF EXISTS `fh_modules`;

CREATE TABLE `fh_modules` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `time_enabled` datetime DEFAULT NULL,
  `time_updated` datetime DEFAULT NULL,
  `state` enum('ENABLED', 'DISABLED') DEFAULT 'DISABLED',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
