# frozen_string_literal: true

require 'minitest/autorun'
require 'processor'

describe Processor do
  before do
    @processor = Processor.new
  end

  describe '.add_points' do
    it 'generates SQL for one point well' do
      mock = MiniTest::Mock.new
      mock.expect(:call, ['fake_result']) do |sql, params|
        # sql should be formed well
        _(sql).must_equal 'INSERT INTO points (point) VALUES (ST_GeomFromText($1))'

        # param types should be proper
        _(params.map { |q| q.class.name }).must_equal ['RGeo::Cartesian::PointImpl']

        # param values should be proper
        _(params.map(&:as_text)).must_equal ['POINT (1.0 2.0)']
      end
      DbWrapper.stub(:exec_params, mock) do
        result = Processor.add_points({ 'Points' => [{ 'type' => 'Point', 'coordinates' => [1, 2] }] })

        # we expect that Processor doesn't break a response from DbWrapper
        _(result).must_equal ['fake_result']
      end
      mock.verify
    end

    it 'generates SQL for two points well' do
      mock = MiniTest::Mock.new
      mock.expect(:call, ['fake_result']) do |sql, params|
        # sql should be formed well
        _(sql).must_equal 'INSERT INTO points (point) VALUES (ST_GeomFromText($1)), (ST_GeomFromText($2))'

        # param types should be proper
        _(params.map { |q| q.class.name }).must_equal %w[RGeo::Cartesian::PointImpl RGeo::Cartesian::PointImpl]

        # param values should be proper
        _(params.map(&:as_text)).must_equal ['POINT (1.0 2.0)', 'POINT (3.0 4.0)']
      end
      DbWrapper.stub(:exec_params, mock) do
        result = Processor.add_points({ 'Points' => [
                                        { 'type' => 'Point', 'coordinates' => [1, 2] },
                                        { 'type' => 'Point', 'coordinates' => [3, 4] }
                                      ] })

        # we expect that Processor doesn't break a response from DbWrapper
        _(result).must_equal ['fake_result']
      end
      mock.verify
    end
  end

  describe '.points_within_radius' do
    it 'generates SQL well' do
      exec_params_mock = MiniTest::Mock.new
      exec_params_mock.expect(:call, ['fake_result']) do |sql, params|
        # sql should be formed well
        _(sql).must_equal 'SELECT ST_AsText(point) FROM points WHERE ST_Distance(point, ST_GeographyFromText($1), $2)'\
          ' <= $3'

        # param types should be proper
        _(params[0]).must_be_kind_of RGeo::Cartesian::PointImpl

        # param values should be proper
        _(params[0].as_text).must_equal 'POINT (1.0 2.0)'
        _(params[1]).must_equal true
        _(params[2]).must_equal 10
      end

      parse_selected_points_mock = MiniTest::Mock.new
      parse_selected_points_mock.expect(:call, ['fake_result2'], [['fake_result']])
      DbWrapper.stub(:exec_params, exec_params_mock) do
        DbWrapper.stub(:parse_selected_points, parse_selected_points_mock) do
          result = Processor.points_within_radius(
            { 'Point' => { 'type' => 'Point', 'coordinates' => [1, 2] }, 'Radius' => 10 }
          )

          # we expect that Processor doesn't break a response from DbWrapper
          _(result).must_equal ['fake_result2']
        end
      end
      exec_params_mock.verify
    end
  end

  describe '.points_within_polygon' do
    it 'generates SQL well' do
      exec_params_mock = MiniTest::Mock.new
      exec_params_mock.expect(:call, ['fake_result']) do |sql, params|
        # sql should be formed well
        _(sql).must_equal 'SELECT ST_AsText(point) FROM points WHERE ST_DWithin(point, ST_GeomFromText($1), 0, $2)'

        # param types should be proper
        _(params[0]).must_be_kind_of RGeo::Cartesian::PolygonImpl

        # param values should be proper
        _(params[0].as_text).must_equal 'POLYGON ((0.0 -5.0, 25.0 -5.0, 15.0 0.0, 25.0 5.0, 0.0 5.0, 0.0 -5.0))'
        _(params[1]).must_equal true
      end

      parse_selected_points_mock = MiniTest::Mock.new
      parse_selected_points_mock.expect(:call, ['fake_result2'], [['fake_result']])
      DbWrapper.stub(:exec_params, exec_params_mock) do
        DbWrapper.stub(:parse_selected_points, parse_selected_points_mock) do
          result = Processor.points_within_polygon(
            { 'Polygon' => { 'type' => 'Polygon',
                             'coordinates' => [[[0, -5], [25, -5], [15, 0], [25, 5], [0, 5], [0, -5]]] } }
          )

          # we expect that Processor doesn't break a response from DbWrapper
          _(result).must_equal ['fake_result2']
        end
      end
      exec_params_mock.verify
    end
  end
end
