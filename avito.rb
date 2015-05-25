# encoding: utf-8
require 'rubygems'
require 'curb'
require 'chunky_png'

class Avito
	attr_accessor :url, :path
	USER_AGENT = 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1650.63 Safari/537.36'
	HOST = 'www.avito.ru'
	def initialize(url)
		self.url = url
		@path = 'phones/'
	end

	def url=(url)
		raise ArgumentError, 'url должен быть String' unless url.is_a? String
		url = 'https://www.avito.ru' + url if url.scan(/^http.+?avito\.ru/sui).size.zero?
		@url = url
	end

	# добавить проверку на существование пути. Создать директории, если необходимо
	def path(path)
		@path = path
	end

	def get_phone(path=nil)
		self.path(path) if path
		id = url.strip.scan(/_(\d+)$/i)
		raise ArgumentError, 'Неверный URL' unless id.is_a? Array
		id = id[0][0].to_i
		cookie_file = "cookie_#{id}"
		curl = Curl::Easy.new do |c|
			c.url = url
			c.useragent = USER_AGENT
			c.enable_cookies = true
			c.cookiefile = cookie_file
			c.cookiejar = cookie_file
			c.ssl_verify_peer = false
			c.ssl_verify_host = false
			c.header_in_body = false
			c.headers = {
					'Host'=>HOST,
					'Content-type'=>'charset=utf-8',
					'Connection'=>'keep-alive'
			}
		end
		curl.perform
		html = curl.body_str.force_encoding('utf-8')
		curl.close
		code_phone = html.scan(/avito\.item\.phone\s*=\s*('|")(.+?)('|")/sui)
		raise StandardError, 'Не найден код телефона на странице' unless code_phone.is_a? Array
		code = get_code(id, code_phone[0][1])
		url_img = "https://www.avito.ru/items/phone/#{id}?pkey=#{code}"
		curl = Curl::Easy.new do |c|
			c.url = url_img
			c.useragent = USER_AGENT
			c.enable_cookies = true
			c.cookiefile = cookie_file
			c.cookiejar = cookie_file
			c.ssl_verify_peer = false
			c.ssl_verify_host = false
			c.header_in_body = false
			c.headers = {
					'Content-type'=>'charset=utf-8',
					'Host'=>HOST,
					'Accept'=>'image/webp',
					'Referer'=>url,
					'Connection'=>'keep-alive'
			}
		end
		curl.perform
		# save png
		filename = "#{@path}#{id.to_s}.png"
		file_png = File.new filename, mode='w'
		file_png.write curl.body
		file_png.close
		curl.close
		# delete cookie
		File.delete cookie_file
		filename
	end

	private

	def get_code(id, code_phone)
		matches = code_phone.scan(/([0-9a-f]+)/sui)
		matches.reverse! if id%2 === 0
		code_phone = matches.join ''
		result = ''
		code_phone.each_char.with_index(0) do |ch, i|
			result += ch if i%3 === 0
		end
		result
	end
end

=begin
avito = Avito.new '/novocheboksarsk/zapchasti_i_aksessuary/turbina_gt1852v_garret_559224246'
p avito.get_phone
=end

png = ChunkyPNG::Image.from_file 'phones/559224246.png'
w = png.width
h = png.height

ar_png = (0...w).collect { Array.new(h) }

w.times do |x|
	h.times do |y|
		ar_png[x][y] = (png[x, y] == 4294967040) ? 0 : 1
	end
end

# разобьем по цифрам
digits = []
new_digit = true
num = 0
ar_png.each_with_index do |row|
	if row.inject { |sum, x| sum + x } < 1
		unless new_digit
			num += 1
			new_digit = true
		end
	else
		new_digit = false
		digits.push [] unless digits[num].is_a? Array
		digits[num].push(row)
	end
end

# повернем все цифры
digits.each_with_index do |digit, index_digit|
	ar = []
	r = digit[0].length
	c = digit.length
	(0...r).collect{ ar.push Array.new(c) }

	(0...c).collect do |col|
		(0...r).collect do |row|
			ar[row][col] = digit[col][row]
		end
	end
	# удалим лишние строки
	new_ar = []
	ar.each do |row|
		new_ar.push row unless row.inject { |sum, x| sum + x } < 2
	end
	digits[index_digit] = new_ar
end

digits.each do |digit|
	if digit.size > 3
		digit.each do |row|
			row.each do |v|
				printf v == 1 ? '#' : ' '
			end
			p ''
		end
		p ' '*10
	end
end

