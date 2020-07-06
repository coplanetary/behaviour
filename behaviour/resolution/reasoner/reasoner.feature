#
# Copyright (C) 2020 Grakn Labs
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

Feature: Reasoning

  Background: Setup base KBs

    Given connection has been opened
    Given connection delete all keyspaces
    Given connection open sessions for keyspaces:
      | completion  |
      | test        |


  Scenario: basic rule
    Given graql define
      """
      define

      name sub attribute, value string;
      company-id sub attribute, value long;

      company sub entity,
        has name,
        key company-id;

      company-has-name sub rule,
      when {
         $c isa company;
      }, then {
         $c has name  $n; $n "the-company";
      };
      """
    Given graql insert
      """
      insert
      $x isa company, has company-id 0;
      """

    When reference kb is completed
    Then for graql query
      """
      match $co has name $n; get;
      """
    Then answer count is correct
    Then answers resolution is correct
    Then test keyspace is complete


  Scenario: compounding rules
    Given graql define
      """
      define

      name sub attribute,
          value string;

      is-liable sub attribute,
          value boolean;

      company-id sub attribute,
          value long;

      company sub entity,
          key company-id,
          has name,
          has is-liable;

      company-has-name sub rule,
      when {
          $c1 isa company;
      }, then {
          $c1 has name $n; $n "the-company";
      };

      company-is-liable sub rule,
      when {
          $c2 isa company, has name $name; $name "the-company";
      }, then {
          $c2 has is-liable $lia; $lia true;
      };
      """
    Given graql insert
      """
      insert
      $co isa company, has company-id 0;
      """

    When reference kb is completed
    Then for graql query
      """
      match $co has is-liable $l; get;
      """
    Then answer count is correct
    Then answers resolution is correct
    Then test keyspace is complete


  Scenario: 2-hop transitivity
    Given graql define
      """
      define
      name sub attribute, value string;

      location-hierarchy-id sub attribute, value long;

      location sub entity,
          abstract,
          key name,
          plays superior,
          plays subordinate;

      area sub location;
      city sub location;
      country sub location;

      location-hierarchy sub relation,
          key location-hierarchy-id,
          relates superior,
          relates subordinate;

      location-hierarchy-transitivity sub rule,
      when {
          (superior: $a, subordinate: $b) isa location-hierarchy;
          (superior: $b, subordinate: $c) isa location-hierarchy;
      }, then {
          (superior: $a, subordinate: $c) isa location-hierarchy;
      };
      """
    Given graql insert
      """
      insert
      $ar isa area, has name "King's Cross";
      $cit isa city, has name "London";
      $cntry isa country, has name "UK";
      (superior: $cntry, subordinate: $cit) isa location-hierarchy, has location-hierarchy-id 0;
      (superior: $cit, subordinate: $ar) isa location-hierarchy, has location-hierarchy-id 1;
      """

    When reference kb is completed
    Then for graql query
      """
      match
      $k isa area, has name $n;
      (superior: $l, subordinate: $k) isa location-hierarchy;
      get;
      """
    Then answer count is correct
    Then answers resolution is correct
    Then test keyspace is complete


  Scenario: 3-hop transitivity
    Given graql define
      """
      define
      name sub attribute,
      value string;

      location-hierarchy-id sub attribute,
          value long;

      location sub entity,
          abstract,
          key name,
          plays location-hierarchy_superior,
          plays location-hierarchy_subordinate;

      area sub location;
      city sub location;
      country sub location;
      continent sub location;

      location-hierarchy sub relation,
          key location-hierarchy-id,
          relates location-hierarchy_superior,
          relates location-hierarchy_subordinate;

      location-hierarchy-transitivity sub rule,
      when {
          (location-hierarchy_superior: $a, location-hierarchy_subordinate: $b) isa location-hierarchy;
          (location-hierarchy_superior: $b, location-hierarchy_subordinate: $c) isa location-hierarchy;
      }, then {
          (location-hierarchy_superior: $a, location-hierarchy_subordinate: $c) isa location-hierarchy;
      };
      """
    Given graql insert
      """
      insert
      $ar isa area, has name "King's Cross";
      $cit isa city, has name "London";
      $cntry isa country, has name "UK";
      $cont isa continent, has name "Europe";
      (location-hierarchy_superior: $cont, location-hierarchy_subordinate: $cntry) isa location-hierarchy, has location-hierarchy-id 0;
      (location-hierarchy_superior: $cntry, location-hierarchy_subordinate: $cit) isa location-hierarchy, has location-hierarchy-id 1;
      (location-hierarchy_superior: $cit, location-hierarchy_subordinate: $ar) isa location-hierarchy, has location-hierarchy-id 2;
      """

    When reference kb is completed
    Then for graql query
      """
      match $lh (location-hierarchy_superior: $continent, location-hierarchy_subordinate: $area) isa location-hierarchy;
      $continent isa continent; $area isa area;
      get;
      """
    Then answer count is correct
    Then answers resolution is correct
    Then test keyspace is complete


  Scenario: queried relation is a supertype of the inferred relation
    Given graql define
      """
      define

      name sub attribute, value string;

      person-id sub attribute, value long;
      siblingship-id sub attribute, value long;

      person sub entity,
          key person-id,
          has name,
          plays sibling;

      man sub person;
      woman sub person;

      family-relation sub relation,
        abstract;

      siblingship sub family-relation,
          key siblingship-id,
          relates sibling;

      a-man-is-called-bob sub rule,
      when {
          $man isa man;
      }, then {
          $man has name $n; $n "Bob";
      };

      bobs-sister-is-alice sub rule,
      when {
          $p isa man, has name $nb; $nb "Bob";
          $p1 isa woman, has name $na; $na "Alice";
      }, then {
          (sibling: $p, sibling: $p1) isa siblingship;
      };
      """
    Given graql insert
      """
      insert
      $a isa woman, has person-id 0, has name "Alice";
      $b isa man, has person-id 1;
      """

    When reference kb is completed
    Then for graql query
      """
      match ($w, $m) isa family-relation; $w isa woman; get;
      """
    Then answer count is correct
    Then answers resolution is correct
    Then test keyspace is complete


  @ignore
  Scenario: querying with a disjunction and a negation
    Given graql define
      """
      define

      name sub attribute,
          value string;

      is-liable sub attribute,
          value boolean;

      company-id sub attribute,
          value long;

      company sub entity,
          key company-id,
          has name,
          has is-liable;

      company-is-liable sub rule,
      when {
          $c2 isa company, has name $n2; $n2 "the-company";
      }, then {
          $c2 has is-liable $l; $l true;
      };
      """
    Given graql insert
      """
      insert
      $c1 isa company, has company-id 0;
      $c1 has name $n1; $n1 "the-company";
      $c2 isa company, has company-id 1;
      $c2 has name $n2; $n2 "another-company";
      """

    When reference kb is completed
    Then for graql query
      """
      match $com isa company;
      {$com has name $n1; $n1 "the-company";} or {$com has name $n2; $n2 "another-company";};
      not {$com has is-liable $liability;};
      get;
      """
    Then answer count is correct
    Then answers resolution is correct
    Then test keyspace is complete


  Scenario: a rule containing a negation
    Given graql define
      """
      define

      name sub attribute,
          value string;

      is-liable sub attribute,
          value boolean;

      company-id sub attribute,
          value long;

      company sub entity,
          key company-id,
          has name,
          has is-liable;

      company-is-liable sub rule,
      when {
          $c2 isa company;
          not {
            $c2 has name $n2; $n2 "the-company";
          };
      }, then {
          $c2 has is-liable $l; $l true;
      };
      """
    Given graql insert
      """
      insert
      $c1 isa company, has company-id 0;
      $c1 has name $n1; $n1 "the-company";
      $c2 isa company, has company-id 1;
      $c2 has name $n2; $n2 "another-company";
      """

    When reference kb is completed
    Then for graql query
      """
      match $com isa company, has is-liable $lia; $lia true; get;
      """
    Then answer count is correct
    Then answers resolution is correct
    Then test keyspace is complete


  Scenario: querying with multiple negations
    Given graql define
      """
      define

      name sub attribute,
          value string;

      is-liable sub attribute,
          value boolean;

      company-id sub attribute,
          value long;

      company sub entity,
          key company-id,
          has name,
          has is-liable;

      company-is-liable sub rule,
      when {
          $c2 isa company;
          $c2 has name $n2; $n2 "the-company";
      }, then {
          $c2 has is-liable $l; $l true;
      };
      """
    Given graql insert
      """
      insert
      $c1 isa company, has company-id 0;
      $c1 has name $n1; $n1 "the-company";
      $c2 isa company, has company-id 1;
      $c2 has name $n2; $n2 "another-company";
      """

    When reference kb is completed
    Then for graql query
      """
      match $com isa company; not { $com has is-liable $lia; $lia true; }; not { $com has name $n; $n "the-company"; }; get;
      """
    Then answer count is correct
    Then answers resolution is correct
    Then test keyspace is complete