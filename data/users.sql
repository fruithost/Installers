DROP TABLE IF EXISTS `fh_users`;

CREATE TABLE `fh_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) DEFAULT NULL,
  `password` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `lost_enabled` enum('YES','NO') DEFAULT 'NO',
  `lost_time` datetime DEFAULT NULL,
  `lost_token` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
