require "vagrant-openstack-plugin/config"

describe VagrantPlugins::OpenStack::Config do
  describe "defaults" do
    let(:vagrant_public_key) { Vagrant.source_root.join("keys/vagrant.pub") }

    subject do
      super().tap do |o|
        o.finalize!
      end
    end

    describe '#api_key' do
      subject { super().api_key }
      it { is_expected.to be_nil }
    end

    describe '#endpoint' do
      subject { super().endpoint }
      it { is_expected.to be_nil }
    end

    describe '#flavor' do
      subject { super().flavor }
      it { is_expected.to eq(/m1.tiny/) }
    end

    describe '#image' do
      subject { super().image }
      it { is_expected.to eq(/cirros/) }
    end

    describe '#server_name' do
      subject { super().server_name }
      it { is_expected.to be_nil }
    end

    describe '#username' do
      subject { super().username }
      it { is_expected.to be_nil }
    end

    describe '#keypair_name' do
      subject { super().keypair_name }
      it { is_expected.to be_nil }
    end

    describe '#ssh_username' do
      subject { super().ssh_username }
      it { is_expected.to be_nil }
    end

    describe '#network' do
      subject { super().network }
      it { is_expected.to be_nil }
    end

    describe '#security_groups' do
      subject { super().security_groups }
      it { is_expected.to be_nil }
    end

    describe '#scheduler_hints' do
      subject { super().scheduler_hints }
      it { is_expected.to be_nil }
    end

    describe '#tenant' do
      subject { super().tenant }
      it { is_expected.to be_nil }
    end

    describe '#proxy' do
      subject { super().proxy }
      it { is_expected.to be_nil }
    end

    describe '#disks' do
      subject { super().disks }
      it { is_expected.to be_nil }
    end

    describe '#ssl_verify_peer' do
      subject { super().ssl_verify_peer }
      it { is_expected.to be_nil }
    end
  end

  describe "overriding defaults" do
    [:api_key,
      :endpoint,
      :flavor,
      :image,
      :server_name,
      :username,
      :keypair_name,
      :network,
      :ssh_username,
      :security_groups,
      :scheduler_hints,
      :tenant,
      :ssl_verify_peer,
      :proxy].each do |attribute|
      it "should not default #{attribute} if overridden" do
        subject.send("#{attribute}=".to_sym, "foo")
        subject.finalize!
        expect(subject.send(attribute)).to eq("foo")
      end
    end
    it "should not default disks if overridden" do
      subject.send("disks=".to_sym, {"name" => "foo", "size" => 10, "description" => "bar"})
      subject.finalize!
      expect(subject.send("disks")).to eq({"name" => "foo", "size" => 10, "description" => "bar"})
    end
  end

  describe "validation" do
    let(:machine) { double("machine") }

    subject do
      super().tap do |o|
        o.finalize!
      end
    end

    context "with good values" do
      it "should validate"
    end

    context "the API key" do
      it "should error if not given"
    end

    context "the public key path" do
      it "should have errors if the key doesn't exist"
      it "should not have errors if the key exists with an absolute path"
      it "should not have errors if the key exists with a relative path"
    end

    context "the username" do
      it "should error if not given"
    end

    context "the disks" do
      it "should not error if not given"
      it "should error if non-array given"
      it "should error if non-hash array element given"
      it "should error if array element hash does not contain all three name, description or size keys"
      it "should not error if array element hash does contain all three name, description and size keys"
    end
  end
end
