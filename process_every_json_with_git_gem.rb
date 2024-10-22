#!/usr/bin/env ruby

# This script reports the total number of commits in the JSON files
# and the number of commits per year, per author

require 'pry'
require 'json'
require 'date'
require 'git'

Git.configure do |config|
  config.binary_path = '/opt/homebrew/bin/git'
end



json_dir_path = ARGV[0]

all_commits = []

# {
#   2023: {
#       committer: cumulative commits
#   }
# }
#
commits_per_year = Hash.new(0)


class CommitEntry
  attr_reader :sha, :committed_date, :author_date, :data, :author_login, :committer_login

  def initialize(data)
    @data = data
    @sha = data['sha']
    parse_dates
    get_logins

  end

  private

  def get_logins
    @author_login = data.dig('author', 'login')
    @committer_login = data.dig('committer', 'login')
  end
  def parse_dates
    author_date_str = data.dig('commit','author', 'date')
    committed_date_str =  data.dig('commit','committer', 'date')

    @author_date = parse_date(author_date_str)
    @committed_date = parse_date(committed_date_str)
  end

  def parse_date(date_str)
    Date.parse(date_str)
  end
end

# Open every JSON file from the original scraped data
# create a new CommitEntry from each commit
Dir.each_child(json_dir_path) do |entry_name|
  next if entry_name.include?('headers')
  file = File.open("#{json_dir_path}/#{entry_name}")
  contents = file.read
  data = JSON.parse(contents)

  data.each do |commit|
    all_commits << CommitEntry.new(commit)
  end

end

class CommitsBreakdown
  attr_reader :hash_of_all_years, :total_commits_for_all_years
  def initialize(all_commits)
    @all_commits=all_commits
    @hash_of_all_years = Hash.new
    process_all_commits
    sum_all_commits
  end

  private
  def sum_all_commits
    total_commits_for_all_years = 0
    hash_of_all_years.each do |key, value|
      puts key
      commits_for_this_year =  hash_of_all_years[key]['total_commits_this_year']
      total_commits_for_all_years += commits_for_this_year
    end
   @total_commits_for_all_years = total_commits_for_all_years
  end

  def yearly_commits_by_author_hash
    @yearly_commits_by_author_hash ||=  Hash.new(0)
  end

  def process_all_commits
    @all_commits.each do |commit|
      year = commit.committed_date.year
      author = commit.author_login
      create_hash_for_new_year_if_none_exists(year)
      count_commit(year, author)
    end
  end
  def create_hash_for_new_year_if_none_exists(year)
    # create a new year if the year doesn't exist already
    puts "creating a new hash for #{year}" unless hash_of_all_years[year]
    hash_of_all_years[year] ||= Hash.new(0)
    hash_of_all_years[year]["total_commits_this_year"] ||= 0
  end

  def count_commit(commit_year, commit_author)
      hash_of_all_years[commit_year][commit_author] += 1
      hash_of_all_years[commit_year]['total_commits_this_year'] += 1
      puts "#{commit_author} has #{hash_of_all_years[commit_year][commit_author] } commits for #{commit_year}"
  end
end

breakdown = CommitsBreakdown.new(all_commits)



puts "Total commits: #{breakdown.total_commits_for_all_years}"

breakdown.hash_of_all_years.each do |key, value|
  puts "#{key} had #{value['total_commits_this_year']} commits"
end

