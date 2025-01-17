require "vanilla/config/boot"
require "vanilla/config/environment"

describe "Generator" do
  let(:output_dir) { Pathname.new File.expand_path("../support/generated", __dir__) }
  let(:sample_dir) { Rails.root.join("app/frontend/types/serializers") }
  let(:serializers) {
    %w[
      VideoWithSongSerializer
      VideoSerializer
      SongSerializer
      SongWithVideosSerializer
      ModelSerializer
      ComposerWithSongsSerializer
      ComposerSerializer
    ]
  }

  def file_for(dir, name)
    dir.join("#{name.chomp("Serializer")}.ts")
  end

  def app_file_for(name)
    file_for(sample_dir, name)
  end

  def output_file_for(name)
    file_for(output_dir, name)
  end

  def expect_generator
    expect(TypesFromSerializers)
  end

  def generate_serializers
    receive(:serializer_interface_content).and_call_original
  end

  original_config = TypesFromSerializers::Config.new TypesFromSerializers.config.clone.to_h.transform_values(&:clone)

  before do
    TypesFromSerializers.instance_variable_set(:@config, original_config)

    # Change the configuration to use a different directory.
    TypesFromSerializers.config do |config|
      config.output_dir = output_dir
    end

    output_dir.rmtree if output_dir.exist?
  end

  # NOTE: We do a manual snapshot test for now, more tests coming in the future.
  it "generates the files as expected" do
    expect_generator.to generate_serializers.exactly(serializers.size).times
    TypesFromSerializers.generate

    # It does not generate routes that don't have `export: true`.
    expect(output_file_for("BaseSerializer").exist?).to be false

    # It generates one file per serializer.
    serializers.each do |name|
      output_file = output_file_for(name)
      expect(output_file.read).to match_snapshot("interfaces_#{name}")
    end

    # It generates an file that exports all interfaces.
    index_file = output_dir.join("index.ts")
    expect(index_file.exist?).to be true
    expect(index_file.read).to match_snapshot("interfaces_index")

    # It does not render if generating again.
    TypesFromSerializers.generate
  end

  it "has a rake task available" do
    Rails.application.load_tasks
    expect_generator.to generate_serializers.exactly(serializers.size).times
    expect { Rake::Task["types_from_serializers:generate"].invoke }.not_to raise_error
  end
end
