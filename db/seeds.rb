# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)
Section.create(section: 'top stories', display_name: 'Top Stories', order:-3)
Section.create(section: 'most popular', display_name: 'Most Popular', order: -2)
Section.create(section: 'trending', display_name: 'Trending', order: -1)
Section.create(section: 'most recent', display_name: 'Most Recent', order: 0)
