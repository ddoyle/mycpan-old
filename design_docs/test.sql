DROP TABLE IF EXISTS `dist`;
CREATE TABLE `dist` (
    `id` INT unsigned NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(255) NOT NULL,
    `abstract` VARCHAR(255) NOT NULL DEFAULT '',
    latest_release_id BIGINT unsigned NOT NULL,
    latest_dev_release_id BIGINT unsigned DEFAULT NULL, 
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`)
);

DROP TABLE IF EXISTS `module`;
CREATE TABLE `module` (
    `id` INT unsigned NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`)
);

DROP TABLE IF EXISTS `release`;
CREATE TABLE `release` (
    `id` INT unsigned NOT NULL AUTO_INCREMENT,
    `dist_id` INT unsigned NOT NULL,
    `version` VARCHAR(64) NULL DEFAULT NULL,
    `is_developer` TINYINT NOT NULL DEFAULT 0,
    `released_on` DATE NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `release` (`dist_id`,`version`)
);

DROP TABLE IF EXISTS `release_meta`;
CREATE TABLE `release_meta` (
    `id` INT unsigned NOT NULL AUTO_INCREMENT,
    `release_id` INT unsigned NOT NULL,
    `key` VARCHAR(128) NOT NULL,
    `value` VARCHAR(128) NOT NULL,
    PRIMARY KEY (`id`),
    INDEX `release` (`release_id`),
    INDEX `key` ( `key` )
    
);

DROP TABLE IF EXISTS `module_release`;
CREATE TABLE `module_release` (
    `id` INT unsigned NOT NULL AUTO_INCREMENT,
    `release_id` INT unsigned NOT NULL,
    `module_id` INT unsigned NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `release_module` (`release_id`,`module_id`)
);

DROP TABLE IF EXISTS `author`;
CREATE TABLE `author` (
    `id` INT(10) unsigned NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(255) NOT NULL,
    `cpanid` VARCHAR(255) NOT NULL,
    `email` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    UNIQUE KEY `cpanid` (`cpanid`)
);

DROP TABLE IF EXISTS `author_release`;
CREATE TABLE `author_release` (
    `id` INT unsigned NOT NULL AUTO_INCREMENT,
    `release_id` INT unsigned NOT NULL,
    `author_id` INT unsigned NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `release_author` (`release_id`,`author_id`)
);




CREATE TABLE IF NOT EXISTS `user` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `password` varchar(512) NOT NULL COMMENT 'SHA512 Hex Digest with SALT',
  `email` varchar(255) NOT NULL,
  `author_id` int(16) unsigned DEFAULT NULL COMMENT 'pause_id is actually 3-9 chars but we''ll make it 16',
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

CREATE TABLE `module` (
  `id` int(16) unsigned not null AUTO_INCREMENT,
  `dist_id` int(10) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `is_core` int(1) not null DEFAULT 0,
  primary key (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;

CREATE TABLE prereq (
  `id` int(16) unsigned not null AUTO_INCREMENT,
  dist_id int(16),
  module_id int(16),
  version varchar(32),
  in_dist int(1),
  is_prereq int(1) not null,
  is_build_prereq int(1) not null,
  is_optional_prereq int(1) not null,
  primary key (id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1;

CREATE INDEX prereq_dist ON prereq (dist);
CREATE INDEX prereq_in_dist ON prereq (in_dist);
CREATE INDEX prereq_requires ON prereq (requires);
CREATE INDEX prereq_is_req ON prereq (is_prereq);
CREATE INDEX prereq_is_buildred ON prereq (is_build_prereq);
CREATE INDEX prereq_is_optreq ON prereq (is_optional_prereq);
CREATE TABLE kwalitee (
  id integer not null,
  dist integer,
  abs_kw integer not null,
  abs_core_kw integer not null,
  kwalitee numeric not null,
  rel_core_kw numeric not null,
  extractable integer not null,
  extracts_nicely integer not null,
  has_version integer not null,
  has_proper_version integer not null,
  no_cpants_errors integer not null,
  has_readme integer not null,
  has_manifest integer not null,
  has_meta_yml integer not null,
  has_buildtool integer not null,
  has_changelog integer not null,
  no_symlinks integer not null,
  has_tests integer not null,
  proper_libs integer not null,
  is_prereq integer not null,
  use_strict integer not null,
  use_warnings integer not null,
  has_test_pod integer not null,
  has_test_pod_coverage integer not null,
  no_pod_errors integer not null,
  has_working_buildtool integer not null,
  manifest_matches_dist integer not null,
  has_example integer not null,
  buildtool_not_executable integer not null,
  has_humanreadable_license integer not null,
  metayml_is_parsable integer not null,
  metayml_conforms_spec_current integer not null,
  metayml_has_license integer not null,
  metayml_conforms_to_known_spec integer not null,
  has_license integer not null,
  prereq_matches_use integer not null,
  build_prereq_matches_use integer not null,
  no_generated_files integer not null,
  run integer,
  has_version_in_each_file integer not null,
  has_tests_in_t_dir integer not null,
  no_stdin_for_prompting integer not null,
  easily_repackageable_by_fedora integer not null,
  easily_repackageable_by_debian integer not null,
  easily_repackageable integer not null,
  fits_fedora_license integer not null,
  metayml_declares_perl_version integer not null,
  no_large_files integer,
  has_separate_license_file integer not null,
  has_license_in_source_file integer not null,
  metayml_has_provides integer not null,
  uses_test_nowarnings integer not null,
  latest_version_distributed_by_debian integer not null,
  has_no_bugs_reported_in_debian integer not null,
  has_no_patches_in_debian integer not null,
  distributed_by_debian integer not null,
  primary key (id)
);
CREATE TABLE uses (
  id integer not null,
  dist integer,
  module text,
  in_dist integer,
  in_code integer not null,
  in_tests integer not null,
  primary key (id)
);
CREATE INDEX uses_dist ON uses (dist);
CREATE INDEX uses_in_code ON uses (in_code);
CREATE INDEX uses_in_dist ON uses (in_dist);
CREATE INDEX uses_in_tests ON uses (in_tests);
CREATE INDEX uses_module ON uses (module);
CREATE TABLE dist (
  id integer not null,
  run integer,
  dist text,
  package text,
  vname text,
  author integer,
  version text,
  version_major text,
  version_minor text,
  extension text,
  extractable integer not null,
  extracts_nicely integer not null,
  size_packed integer not null,
  size_unpacked integer not null,
  released timestamp without time zone,
  files integer not null,
  files_list text,
  dirs integer not null,
  dirs_list text,
  symlinks integer not null,
  symlinks_list text,
  bad_permissions integer not null,
  bad_permissions_list text,
  file_makefile_pl integer not null,
  file_build_pl integer not null,
  file_readme text,
  file_manifest integer not null,
  file_meta_yml integer not null,
  file_signature integer not null,
  file_ninja integer not null,
  file_test_pl integer not null,
  file_changelog text,
  dir_lib integer not null,
  dir_t integer not null,
  dir_xt integer not null,
  broken_module_install text not null,
  manifest_matches_dist integer not null,
  buildfile_executable integer not null,
  license text,
  metayml_is_parsable integer not null,
  file_license integer not null,
  needs_compiler integer not null,
  got_prereq_from text,
  is_core integer not null,
  file__build integer not null,
  file_build integer not null,
  file_makefile integer not null,
  file_blib integer not null,
  file_pm_to_blib integer not null,
  stdin_in_makefile_pl integer not null,
  stdin_in_build_pl integer not null,
  external_license_file text,
  file_licence text,
  licence_file text,
  license_file text,
  license_type text,
  no_index text,
  ignored_files_list text,
  license_in_pod integer not null,
  license_from_yaml text,
  license_from_external_license_file text,
  test_files_list text,
  primary key (id)
);
CREATE INDEX dist_auth ON dist (author);
CREATE UNIQUE INDEX dist_dist_key ON dist (dist);
CREATE UNIQUE INDEX dist_package_key ON dist (package);
CREATE UNIQUE INDEX dist_vname_key ON dist (vname);
CREATE TABLE author (
  id integer not null,
  pauseid text,
  name text,
  email text,
  average_kwalitee numeric,
  num_dists integer not null,
  rank integer not null,
  prev_av_kw numeric,
  prev_rank integer not null,
  average_total_kwalitee numeric,
  primary key (id)
);
CREATE INDEX auth_av ON author (average_kwalitee);
CREATE INDEX auth_num ON author (num_dists);
CREATE INDEX auth_pav ON author (prev_av_kw);
CREATE INDEX auth_prank ON author (prev_rank);
CREATE INDEX auth_rank ON author (rank);
CREATE UNIQUE INDEX author_pauseid_key ON author (pauseid);
