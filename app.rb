require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'
require 'pony'
require 'sqlite3'

def is_barber_exists? db, name
  db.execute('select * from Barbers where name=?', [name]).length > 0
end

def seed_db db, barbers
   barbers.each do |barber|
      if !is_barber_exists? db, barber
        db.execute 'insert into Barbers (name) values (?)', [barber]
      end
   end
end

def get_db
  db = SQLite3::Database.new 'barbershop.db'
  db.results_as_hash = true
  db
end

configure do
  db = get_db
  db.execute 'CREATE TABLE IF NOT EXISTS
    "Users"
    (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "username" TEXT,
      "phone" TEXT,
      "datastamp" TEXT,
      "barber" TEXT,
      "color" TEXT
    )'

    db.execute 'CREATE TABLE IF NOT EXISTS
    "Barbers"
    (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "name" TEXT
    )'

    seed_db db, ['Walter White','Jessie Pinkman','Gus Fring','Mike Ehrmantraut']


  enable :sessions
end

get '/about' do 
  @error = 'something wrong!'
  erb :about
end

get '/visit' do
  erb :visit
end

get '/contacts' do
  erb :contacts
end

post '/visit' do
  # user_name, phone, date_time
  @user_name = params[:user_name]
  @phone = params[:phone]
  @date_time = params[:date_time]
  @barber = params[:barber]
  @color = params[:color]

  hh = {:user_name => 'Введите имя', 
    :phone => 'Введите телефон', 
    :date_time => 'Введите дату и время'}

    @error = hh.select {|key,_| params[key] == ''}.values.join(', ')

    if @error != ''
      return erb :visit
    end

    db = get_db
    db.execute 'insert into 
      Users 
      (
        username, 
        phone, 
        datestamp, 
        barber, 
        color
      )
      values(?,?,?,?,?)', [@user_name, @phone, @date_time, @barber, @color]

  @title = "Thank you!"
  @message = "Уважаемый #{@user_name}, мы ждём вас #{@date_time} у выбранного парикмахера #{@barber}. Ваш цвет #{@color}"

  # запишем в файл то, что ввёл клиент
  # f = File.open './public/users.txt', 'a'
  # f.write "User: #{@user_name}, phone: #{@phone}, date and time: #{@date_time}. Barber: #{@barber}. Ваш цвет #{@color}.\n"
  # f.close

  erb :visit
end

get '/showusers' do
  db = get_db

  @results = db.execute 'SELECT * FROM Users'

  erb :showusers
end

post '/contacts' do
  @email = params[:email]
  @message = params[:message]

  hh = {:email => 'Введите адрес почты', :message => 'Введите сообщение'}

   @error = hh.select {|key,_| params[key] == ''}.values.join(', ')

    if @error != ''
      return erb :contacts
    end
  #Запись в файл
  # f = File.open './public/contacts.txt', 'a'
  # f.write "Email: #{@email}, Message: #{@message}\n"
  # f.close

  #Отправка на мыло
  Pony.mail(
    :mail => 'dellvesna@gmail.com',
    :to => params[:email],
    :subject => "Test",
    :body => params[:message],
    :port => '587',
    :via => :smtp,
    :via_options => { 
      :address              => 'smtp.gmail.com', 
      :port                 => '587', 
      :enable_starttls_auto => true, 
      :user_name            => 'dellvesna', 
      :password             => 'zO51Nc6Y', 
      :authentication       => :plain, 
      :domain               => 'localhost.localdomain'
    })



  erb :contacts
end

helpers do
  def username
    session[:identity] ? session[:identity] : 'Hello stranger'
  end
end

before '/secure/*' do
  unless session[:identity]
    session[:previous_url] = request.path
    @error = 'Sorry, you need to be logged in to visit ' + request.path
    halt erb(:login_form)
  end
end

get '/' do
  erb 'Can you handle a <a href="/secure/place">secret</a>?'
end

get '/login/form' do
  erb :login_form
end

post '/login/attempt' do
  @username = params[:username]
  @password = params[:password]

  if @username == 'admin' && @password == 'secret'
    session[:identity] = params['username']
    where_user_came_from = session[:previous_url] || '/'
    redirect to where_user_came_from
  elsif @username == 'admin' && @password == 'admin'
    @message = 'HA-HA! Nice try! '
    erb :login_form
  else
    @message = 'Incorrect password!'
    erb :login_form
  end

end

get '/logout' do
  session.delete(:identity)
  erb "<div class='alert alert-message'>Logged out</div>"
end

get '/secure/place' do
  erb 'This is a secret place that only <%=session[:identity]%> has access to!'
end