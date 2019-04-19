DROP TABLE IF EXISTS `fh_repositorys`;

CREATE TABLE `fh_repositorys` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `url` varchar(255) DEFAULT NULL,
  `time_updated` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;

INSERT INTO `fh_repositorys` VALUES (NULL, 'https://github.com/fruithost/Modules/', NULL);
