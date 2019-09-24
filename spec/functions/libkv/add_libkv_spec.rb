require 'spec_helper'

describe 'libkv::add_libkv' do

  it 'should add libkv accessors to catalog instance at global scope when none exists' do
    is_expected.to run.with_params()

    expect( catalogue.respond_to?(:libkv) ).to be true
    expect( catalogue.respond_to?(:libkv=) ).to be true
    [ :delete,
      :deletetree,
      :exists,
      :get,
      :list,
      :put
    ].each do |api_method|
      expect( catalogue.libkv.respond_to?(api_method) ).to be true
    end
  end

  it 'should use existing libkv adapter instance when catalog has libkv accessors' do
    is_expected.to run.with_params()
    libkv_class_id1 = catalogue.libkv.to_s

    is_expected.to run.with_params()
    libkv_class_id2 = catalogue.libkv.to_s

    expect(libkv_class_id1).to eq libkv_class_id2
  end

  it 'should fail when libkv.rb does not exist' do
    allow(File).to receive(:exists?).and_return(false)
    is_expected.to run.with_params().and_raise_error(LoadError, /libkv Internal Error: unable to load .* File not found/)
  end

  it 'should fail when libkv.rb is malformed Ruby' do
    allow(File).to receive(:read).and_return("if true\n")
    is_expected.to run.with_params().and_raise_error(LoadError, /libkv Internal Error: unable to load .* syntax error/)
 end

end
