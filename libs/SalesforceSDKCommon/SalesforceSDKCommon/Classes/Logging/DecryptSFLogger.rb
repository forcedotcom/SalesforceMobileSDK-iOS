#!/usr/bin/env ruby
require 'base64'
require 'openssl'

def decrypt( cipherBase64, key )
    cipher = Base64.decode64( cipherBase64 )
    aes = OpenSSL::Cipher::AES.new(256, :CBC).decrypt
    aes.key = Digest::SHA256.digest( key )
    aes.iv =  Digest::SHA256.digest( "ancfjncafjghcy4398439834noiconiwre" )
    return aes.update( cipher ) + aes.final
end

def indexToParse(line)
  padding = 0
  index = line.index('>:')
  if index == nil
    index = line.index(']')
    if index != nil
      padding = 2
    end
  else
    padding = 3
  end
  return index + padding
end

filepath = ARGV[0]
begin
  File.open(filepath, "r") do |infile|
    while (line = infile.gets)
      begin
        substring = line[indexToParse(line), line.length]
        decryptedString = decrypt(substring, "Howmuchwoodwouldawoodchuckchuckifawoodchuckcouldchuckchucksofwood?") + "\n"
        beginingSubString = line[0, indexToParse(line)]
        puts "#{beginingSubString}#{decryptedString}"
      rescue => err
       
        puts "*#{line}"
      end
    end
  end
rescue => err
  puts "Exception: #{err}"
end
# print decrypt( ARGV[0], ARGV[1] ) + "\n"