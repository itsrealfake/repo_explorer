require 'csv'
require 'pry'

csv_file_name = ARGV[0]
begin_row = ARGV[1].to_i
complete_row = ARGV[2].to_i

puts csv_file_name
puts begin_row
puts complete_row

contributor_node_ids = Hash.new(0)

def iterate_over_n_rows(csv_file, start_row = 1, end_row = -1)
  commits_by_contributor = Hash.new(0)
  count_of_all_commits = 0
  # puts "doin stuff"
  CSV.read(csv_file, headers: true).each_with_index do |row, index|
    # starting with the first row that isn't headers, give the details of the row.
    #

    commits_by_contributor[row['commit_commiter_login']] += 1
    count_of_all_commits +=1
    # puts commits_by_contributor.to_h
# binding.pry
    #row_number = row['id']
    # if start_row <= row_number && (end_row == -1 || row_number <= end_row)
    #   callback_to_iterate(row)
    # end
  end

  # Output the contributor name and number of pull requests merged
  CSV.open('test.csv', "a+") do |csv|
	total_percent = 0
	commits_by_contributor.each do |contributor, commits|
	  # the percentage of total commits
	  percentage_of_total_commits = (commits.to_f / commits_by_contributor.values.sum.to_f * 100.0).round(2)
	  total_percent += percentage_of_total_commits
	  csv << [contributor, ' ' ,commits,  " #{percentage_of_total_commits}%"]
	end
	csv << [ 'Total %', total_percent, 'Total Commits', commits_by_contributor.values.sum.to_f]
  end



end

def callback_to_iterate(row)
  puts "i see #{row['id']}"
end

iterate_over_n_rows(csv_file_name, begin_row, complete_row)
