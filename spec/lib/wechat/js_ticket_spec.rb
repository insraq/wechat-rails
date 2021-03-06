require 'spec_helper'

describe Wechat::JsTicket do

  let(:ticket_file) { Rails.root.join("tmp/js_ticket") }

  let(:server_response_1) {
    {"errcode" => 0, "errmsg" => "ok", "ticket" => "ticket1", "expires_in" => 5}
  }
  let(:server_response_2) {
    {"errcode" => 0, "errmsg" => "ok", "ticket" => "ticket2", "expires_in" => 5}
  }
  let(:server_response_expire) {
    {"errcode" => 42001, "errmsg" => "token expire", "ticket" => "ticket2", "expires_in" => 5}
  }
  let(:client) { double(:client) }
  subject do
    Wechat::JsTicket.new(client, "access_token", ticket_file)
  end
  before :each do
    allow(subject.access_token).to receive(:token).and_return("access_token")
    allow(subject.access_token).to receive(:refresh).and_return("new_access_token")

  end
  after :each do
    File.delete(ticket_file) if File.exist?(ticket_file)
  end
  context "#ticket" do

    it "refresh js ticket if js ticket file didn't exist" do
      allow(subject.client).to receive(:get)
                                   .with('ticket/getticket', params: {access_token: subject.access_token.token, type: 'jsapi'})
                                   .and_return(server_response_1)
      expect(File.exist? ticket_file).to be false
      expect(subject.ticket).to eq("ticket1")
      expect(File.exist? ticket_file).to be true
    end

    it "refresh js ticket if ticket file is invalid " do
      allow(subject.client).to receive(:get)
                                   .with('ticket/getticket', params: {access_token: subject.access_token.token, type: 'jsapi'})
                                   .and_return(server_response_1)

      File.open(ticket_file, 'w') { |f| f.write("broken file content") }
      expect(subject.ticket).to eq("ticket1")
    end

    it "raise exception if refresh failed " do
      allow(client).to receive(:get).and_raise("error")
      expect { subject.ticket }.to raise_error("error")
    end

    it "refresh token and retry if token expires" do
      call_count = 0

      allow(subject.client).to receive(:get)
                                   .with('ticket/getticket', params: {access_token: subject.access_token.token, type: 'jsapi'}) do
        call_count +=1
        if call_count == 1
          raise(Wechat::AccessTokenExpiredError)
        else
          server_response_1
        end

      end
      expect(subject.ticket).to eq "ticket1"

    end
    it 'should get same ticket within 5 seconds' do
      allow(subject.client).to receive(:get)
                                   .with('ticket/getticket', params: {access_token: subject.access_token.token, type: 'jsapi'})
                                   .and_return(server_response_1)
      ticket1 = subject.ticket
      sleep 4.seconds
      allow(subject.client).to receive(:get)
                                   .with('ticket/getticket', params: {access_token: subject.access_token.token, type: 'jsapi'})
                                   .and_return(server_response_2)
      ticket2 = subject.ticket
      expect(ticket1).to eq(ticket2)
    end

    it 'should get different tickets after 5 seconds' do
      allow(subject.client).to receive(:get)
                                   .with('ticket/getticket', params: {access_token: subject.access_token.token, type: 'jsapi'})
                                   .and_return(server_response_1)
      ticket1 = subject.ticket
      sleep 6.seconds
      allow(subject.client).to receive(:get)
                                   .with('ticket/getticket', params: {access_token: subject.access_token.token, type: 'jsapi'})
                                   .and_return(server_response_2)
      ticket2 = subject.ticket
      expect(ticket1).not_to eq(ticket2)

    end
  end

end