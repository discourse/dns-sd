module ExampleGroupMethods
  def use_mock_resolver
    let(:mock_resolver) { instance_double(Resolv::DNS) }
    before(:each) do
      allow(Resolv::DNS).to receive(:new).and_return(mock_resolver)
    end
  end
end
