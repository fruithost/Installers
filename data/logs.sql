DROP TABLE IF EXISTS `fh_logs`;

CREATE TABLE `fh_logs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) DEFAULT NULL,
  `target` varchar(255) DEFAULT NULL,
  `text` longtext DEFAULT NULL,
  `time` datetime DEFAULT NULL,
  `type` enum('DOMAIN') DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
