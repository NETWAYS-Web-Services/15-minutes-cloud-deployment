from flask import Flask, render_template, request, redirect, url_for

app = Flask(__name__)

# In-memory storage for todo items
# Each item is a dict: {'id': int, 'task': str, 'completed': bool}

todos = []
next_id = 1

@app.route('/', methods=['GET', 'POST'])
def index():
    global next_id
    global todos
    
    if request.method == 'POST':
        # Determine action based on submitted form
        if 'new_task' in request.form:
            task_text = request.form['new_task'].strip()
            if task_text:
                todos.append({'id': next_id, 'task': task_text, 'completed': False})
                next_id += 1
        elif 'toggle_id' in request.form:
            toggle_id = int(request.form['toggle_id'])
            for item in todos:
                if item['id'] == toggle_id:
                    item['completed'] = not item['completed']
                    break
        elif 'delete_id' in request.form:
            delete_id = int(request.form['delete_id'])
            todos = [item for item in todos if item['id'] != delete_id]
        return redirect(url_for('index'))
    return render_template('index.html', todos=todos)

if __name__ == '__main__':
    # Run the Flask development server
    app.run(host='0.0.0.0', port=5000, debug=False)
