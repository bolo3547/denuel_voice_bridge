from flask import Flask
app = Flask(__name__)

@app.route('/')
def hi():
    return 'Hello!'

@app.route('/health')
def health():
    return {'status': 'ok'}

if __name__ == '__main__':
    print("Starting test server...")
    app.run(host='0.0.0.0', port=5001, debug=False, use_reloader=False)
