require 'activerecord'
require 'markaby'
require 'bluecloth'

Merb::Router.prepare do |r|
  r.match('/:reference.js').to(:controller => 'backchat', :action => 'embed').name(:embed)
  r.match('/comments/:reference').to(:controller => 'backchat', :action => 'show', :method => 'get').name(:show)
  r.match('/comments/create/:reference').to(:controller => 'backchat', :action => 'create', :method => 'post').name(:create)
end

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

class Backchat < Merb::Controller
  def embed
    script = "document.write('#{render_comments}');" 
    script += "document.write('#{styles}');" if params[:css]
    render script, :format => :js
  end

  def show
    render_comments
  end
  
  def create
    Comment.create!(params[:comment].merge(:reference => params[:reference]))
    store_credentials
    redirect request.referer
  end
  
  private
  
  def store_credentials
    session[:author_name] = params[:comment][:author_name] rescue nil
    session[:author_email] = params[:comment][:author_email] rescue nil
  end
  
  def styles
    "<style>
    .backchat p { margin: 5px }
    .backchat ul { list-style: none; padding-left: 0 }
    .backchat li { background-color: #eee; padding: 0.2em 0.5em 0.5em 0.5em;  }
    .backchat li .content { background-color: #fff; padding: 0.5em }
    .backchat form label { display: block; vertical-align: top }
    .backchat form input, .backchat form textarea { width: 20em }
    .backchat form textarea { height: 10em }
    </style>".gsub("\n", " ")
  end
  
  def render_comments
    comments = Comment.find_all_by_reference(params[:reference])
    Markaby::Builder.new({:params => params, :comments => comments, :controller => self}) do
      div.backchat do
        if @comments.any?
          h2 "#{@comments.length} comment(s)"
          ul do
            @comments.each do |comment|
              li do
                p.author "#{comment.author_name || 'someone'} said (#{comment.created_at.strftime("%Y-%m-%d %H:%M")})"
                div.content { BlueCloth.new(comment.content).to_html }
              end
            end
          end
        else
          h2 "No comments"
        end
        form(:action => "http://#{@controller.request.host}" + 
                        @controller.url(:create, :reference => params[:reference]), 
             :method => "post") do
          label { "Name: " + input(:type => "text", :name => "comment[author_name]", :value => @controller.session[:author_name]) }
          label { "Email: " + input(:type => "text", :name => "comment[author_email]", :value => @controller.session[:author_email]) }
          label { "Comment: " + textarea(:name => "comment[content]") }
          button(:type => "submit") { "Post!" }
        end
      end
    end.to_s
  end
end

Merb.config do
  session_store "cookie"
  session_secret_key "rabbit rabbit rabbit rabiit"
  exception_details = true
end