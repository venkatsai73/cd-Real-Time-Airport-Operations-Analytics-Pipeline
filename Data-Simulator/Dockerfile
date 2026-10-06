# Dockerfile for the Data Simulator

# Start with a slim, official Python base image
FROM python:3.12-slim


# Set the working directory inside the container
WORKDIR /app

# Copy the requirements file first to leverage Docker's layer caching
COPY requirements.txt .

# Install the Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code (our simulator script)
COPY . .

# Set the command to run when the container starts
CMD ["python", "data_sim.py"]
