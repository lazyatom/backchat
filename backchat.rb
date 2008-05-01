require 'rubygems'
require 'sinatra'
require 'markaby'
require 'activerecord'
require 'bluecloth'

ActiveRecord::Base.establish_connection({
  :adapter => 'sqlite3',
  :database => File.basename(__FILE__, '.rb') + '.db'
})

class Comment < ActiveRecord::Base
  def self.create_table
    ActiveRecord::Migration.create_table(table_name) do |t|
      t.string :reference
      t.string :author_email
      t.string :author_name
      t.text :content
      t.datetime :created_at
    end
  end
end

Comment.create_table unless ActiveRecord::Base.connection.tables.include?(Comment.table_name)

Styles = <<-EOS
.backchat p { margin: 5px }
.backchat ul { list-style: none; padding-left: 0 }
.backchat li { background-color: #eee; padding: 0.2em 0.5em 0.5em 0.5em;  }
.backchat li .content { background-color: #fff; padding: 0.5em }
EOS

# Write the comments directly into the requesting page
get "/:reference.js" do
  #puts application.env
  header 'Content-Type' => 'text/js'
  "document.write('#{comments(params)}');"
end

def server_address
  # TODO: how to figure this out programmatically?
  "http://localhost:4567"
end

# Render the comments HTML
def comments(params)
  comments = Comment.find_all_by_reference(params[:reference])
  Markaby::Builder.new({:params => params, :comments => comments}) do
    div.backchat do
      if @comments.any?
        h2 "#{@comments.length} comment(s)"
        ul do
          @comments.each do |comment|
            li do
              p.author "#{comment.author_name} said (#{comment.created_at.strftime("%Y-%m-%d %H:%M")})"
              div.content { BlueCloth.new(comment.content).to_html }
            end
          end
        end
      else
        h2 "No comments"
      end
      form(:action => "#{server_address}/#{@params[:reference]}", :method => "post") do
        label { "Name: " + input(:type => "text", :name => "author_name") }
        label { "Email: " + input(:type => "text", :name => "author_email") }
        label { "Comment: " + textarea(:name => "content") }
        button(:type => "submit") { "Post!" }
      end
    end
  end.to_s
end

# Show the comments, but as HTML
get "/:reference" do
  Markaby::Builder.new({:params => params}) do
    html do
      head do
        style Styles
      end
      body do
        comments(params)
      end
    end
  end.to_s
end

# Post a new comment for this reference
post "/:reference" do
  comment_attributes = params.dup.reject { |k,v| k == :format }
  Comment.create!(comment_attributes)
  
  # TODO: we need to redirect BACK here.
  redirect "/#{params[:reference]}"
end