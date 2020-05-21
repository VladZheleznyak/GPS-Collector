require 'json'

class GpsCollector
  def call(env)
    req = Rack::Request.new(env)

    # TODO: parse after method/path check
    body = req.body.read
    begin
      body_json = JSON.parse(body)
    rescue JSON::ParserError
      return error_response('Error in data, should be JSON')
    end
    method = env['REQUEST_METHOD']
    path = env['PATH_INFO'][1..-1]

    if (method == 'POST') && (path == 'add_points')
      add_points(body_json)
    elsif (method == 'GET') && (path == 'points_within_radus')
      points_within_radus(body_json)
    elsif (method == 'GET') && (path == 'points_within_polygon')
      points_within_polygon(body_json)
    else
      error_response("Unknown method and path combination: #{method} #{path}")
    end
  end

  protected

  def error_response(msg)
    # TODO: 400 to constant
    [400, {'Content-Type' => 'application/json'}, [{'error' => msg}.to_json]]
  end

  def ok_response(answer)
    [400, {'Content-Type' => 'application/json'}, [answer.to_json]]
  end

  def add_points(body_json)
    ok_response({})
  end

  def points_within_radus(body_json)
    ok_response({})
  end

  def points_within_polygon(body_json)
    ok_response({})
  end
end